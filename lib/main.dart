import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
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

class MyApp extends StatelessWidget {
  MyApp({super.key});
  final ShellProvider shellModel = ShellProvider();
  final AppProvider appModel = AppProvider();
  final LayersProvider layersProvider = LayersProvider();
  @override
  Widget build(final BuildContext context) {
    return MultiProvider(
      // ignore: always_specify_types
      providers: [
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final _) => shellModel),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final _) => appModel),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final _) => layersProvider),
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
        home: shortCutsForMainApp(
          shellModel,
          appModel,
          const MainScreen(),
        ),
      ),
    );
  }
}
