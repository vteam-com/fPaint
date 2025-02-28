import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/pages/platforms_page.dart';
import 'package:fpaint/pages/settings_page.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/shortcuts.dart';
import 'package:provider/provider.dart';

/// The main entry point for the Flutter Paint App.
///
/// This class sets up the app's theme, keyboard shortcuts, and actions for undo, redo, and saving the file.
/// The [MainScreen] widget is the root of the app's UI.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(MyApp());
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
      // ignore: always_specify_types
      providers: [
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final _) => shellProvider),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final _) => appProvider),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final _) => layersProvider),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final _) => undoProvider),
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
        // Define routes with a PlatformsPage route added.
        routes: <String, WidgetBuilder>{
          '/': (final BuildContext context) => shortCutsForMainApp(
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
