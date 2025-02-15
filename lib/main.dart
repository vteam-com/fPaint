import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/models/shell_model.dart';
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
  final shellModel = ShellModel();
  final appModel = AppModel();
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => shellModel),
        ChangeNotifierProvider(create: (_) => appModel),
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
