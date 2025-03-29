import 'dart:io';
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

/// The main entry point for the Flutter Paint App.
///
/// This class sets up the app's theme, keyboard shortcuts, and actions for undo, redo, and saving the file.
/// The [MainScreen] widget is the root of the app's UI.

late MyApp mainApp;
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Only enable system UI mode for iOS/Android.
  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // Platform channel for file opening.
  const MethodChannel('com.vteam.fpaint/file')
      .setMethodCallHandler((final MethodCall call) async {
    if (call.method == 'fileOpened') {
      final String filePath = call.arguments as String;
      // Clear and load  - TODO confirm with user before loosing existing work
      mainApp.appProvider.layers.clear();
      await openFileFromPath(mainApp.appProvider.layers, filePath);
    }
  });

  mainApp = MyApp();

  runApp(mainApp);
}

/// The main entry point for the Flutter Paint App.
///
/// This class sets up the app's theme, keyboard shortcuts, and actions for undo, redo, and saving the file.
/// The [MainScreen] widget is the root of the app's UI.
class MyApp extends StatelessWidget {
  MyApp({super.key});
  final ShellProvider shellProvider = ShellProvider();
  final AppProvider appProvider = AppProvider();
  final LayersProvider layersProvider = LayersProvider();
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
