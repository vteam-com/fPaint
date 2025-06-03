import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/pages/platforms_page.dart';
import 'package:fpaint/pages/settings_page.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/shortcuts.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// The global instance of the [MyApp] widget.
///
/// This variable is initialized in the [main] function and used to access the app's providers.
late MyApp mainApp;

/// The main function is the entry point of the Flutter application.
///
/// It initializes the Flutter widgets, sets up the system UI mode,
/// handles file opening events, and runs the app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    // Enable Impeller for better performance
    // This reduces shader compilation jank on mobile platforms
    if (Platform.isIOS || Platform.isAndroid) {
      // Impeller is enabled by default on iOS, but we can explicitly set it
      // For Android, we need to opt-in
      PlatformDispatcher.instance.onError = (final Object error, final StackTrace stack) {
        // Log any Impeller-related errors
        if (kDebugMode) {
          print('Unhandled error: $error');
        }
        return true;
      };
      // Only enable system UI mode for iOS/Android.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await windowManager.ensureInitialized();

      // Tell window_manager we want to intercept close
      await windowManager.setPreventClose(true);

      windowManager.addListener(MyWindowListener());

      await restoreWindowState();
    }

    // Platform channel for file opening.
    const MethodChannel('com.vteam.fpaint/file').setMethodCallHandler((final MethodCall call) async {
      if (call.method == 'fileOpened') {
        final String filePath = call.arguments as String;

        // Check if there are unsaved changes before clearing
        if (mainApp.appProvider.layers.hasChanged) {
          final bool shouldProceed =
              await showDialog<bool>(
                context: mainApp.navigatorKey.currentContext!,
                builder: (final BuildContext context) => AlertDialog(
                  title: const Text('Unsaved Changes'),
                  content: const Text(
                    'You have unsaved changes. Do you want to discard them and open the new file?',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Discard and Open'),
                    ),
                  ],
                ),
              ) ??
              false;

          if (!shouldProceed) {
            return;
          }
        }

        mainApp.appProvider.layers.clear();
        final bool success = await openFileFromPath(
          context: mainApp.navigatorKey.currentContext!,
          layers: mainApp.appProvider.layers,
          path: filePath,
        );

        // Update the shell provider with the file name if successful
        if (success) {
          mainApp.shellProvider.loadedFileName = filePath;
        }
      }
    });
  }

  mainApp = MyApp();

  runApp(mainApp);
}

/// The main entry point for the Flutter Paint App.
///
/// This class sets up the app's theme, keyboard shortcuts, and actions for undo, redo, and saving the file.
/// The [MainScreen] widget is the root of the app's UI.
class MyApp extends StatelessWidget {
  /// Creates a [MyApp] widget.
  MyApp({super.key});

  /// Global navigator key to access context from outside of the widget tree
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Provides shell-level functionalities and states.
  final ShellProvider shellProvider = ShellProvider();

  /// Provides application-level functionalities and states.
  final AppProvider appProvider = AppProvider();

  /// Provides functionalities and states for managing layers.
  final LayersProvider layersProvider = LayersProvider();

  /// Provides functionalities for undo and redo operations.
  final UndoProvider undoProvider = UndoProvider();

  @override
  Widget build(final BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final BuildContext _) => shellProvider),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final BuildContext _) => appProvider),
        // ignore: always_specify_types
        ChangeNotifierProvider(
          create: (final BuildContext _) => layersProvider,
        ),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final BuildContext _) => undoProvider),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Flutter Paint App',
        theme: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.lightBlue,
            secondary: Colors.blue,
          ),
          sliderTheme: SliderThemeData(
            activeTrackColor: Colors.blue.shade800,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.blue.shade100,
            overlayColor: Colors.blue.withAlpha(100),
          ),
        ),
        routes: <String, WidgetBuilder>{
          '/': (final BuildContext context) => shortCutsForMainApp(
            context,
            shellProvider,
            appProvider,
            const MainScreen(),
          ),
          '/settings': (final _) => const SettingsPage(),
          '/platforms': (final _) => const PlatformsPage(),
        },
      ),
    );
  }
}

Future<void> saveWindowState() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final Rect bounds = await windowManager.getBounds();

  await prefs.setDouble('window_x', bounds.left);
  await prefs.setDouble('window_y', bounds.top);
  await prefs.setDouble('window_width', bounds.width);
  await prefs.setDouble('window_height', bounds.height);
}

Future<void> restoreWindowState() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final bool hasData =
      prefs.containsKey('window_x') &&
      prefs.containsKey('window_y') &&
      prefs.containsKey('window_width') &&
      prefs.containsKey('window_height');

  if (hasData) {
    final double x = getSafeDouble(prefs, 'window_x')!;
    final double y = getSafeDouble(prefs, 'window_y')!;
    final double width = getSafeDouble(prefs, 'window_width')!;
    final double height = getSafeDouble(prefs, 'window_height')!;

    await windowManager.setBounds(Rect.fromLTWH(x, y, width, height));
  } else {
    // Optional: set a default window size
    await windowManager.setSize(const Size(800, 600));
    await windowManager.center();
  }

  await windowManager.show();
  await windowManager.focus();
}

double? getSafeDouble(final SharedPreferences prefs, final String key) {
  final Object? value = prefs.get(key);
  if (value is double) {
    return value;
  } else if (value is int) {
    return value.toDouble(); // gracefully convert
  }
  return null;
}

class MyWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      // Prevent the close, do your save logic first
      await saveWindowState();

      // Then actually destroy the window
      await windowManager.destroy();
    }
  }
}
