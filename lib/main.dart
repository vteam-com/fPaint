import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/main_screen.dart';
import 'package:provider/provider.dart';
import 'models/app_model.dart';

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
  final appModel = AppModel();
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => appModel,
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
        home: Shortcuts(
          shortcuts: {
            // Undo
            LogicalKeySet(
              LogicalKeyboardKey.control,
              LogicalKeyboardKey.keyZ,
            ): const UndoIntent(),

            LogicalKeySet(
              LogicalKeyboardKey.meta,
              LogicalKeyboardKey.keyZ,
            ): const UndoIntent(),

            // Redo
            LogicalKeySet(
              LogicalKeyboardKey.control,
              LogicalKeyboardKey.keyZ,
              LogicalKeyboardKey.shift,
            ): const RedoIntent(),

            LogicalKeySet(
              LogicalKeyboardKey.meta,
              LogicalKeyboardKey.keyZ,
              LogicalKeyboardKey.shift,
            ): const RedoIntent(),

            // Save
            LogicalKeySet(
              LogicalKeyboardKey.control,
              LogicalKeyboardKey.keyS,
            ): const SaveIntent(),

            LogicalKeySet(
              LogicalKeyboardKey.meta,
              LogicalKeyboardKey.keyS,
            ): const SaveIntent(),

            // Escape
            LogicalKeySet(
              LogicalKeyboardKey.escape,
            ): const EscapeIntent(),

            // Delete/Backspace
            LogicalKeySet(
              LogicalKeyboardKey.delete,
            ): const DeleteIntent(),
          },
          child: Actions(
            actions: {
              UndoIntent: CallbackAction<UndoIntent>(
                onInvoke: (UndoIntent intent) => appModel.undo(),
              ),
              RedoIntent: CallbackAction<RedoIntent>(
                onInvoke: (RedoIntent intent) => appModel.redo(),
              ),
              SaveIntent: CallbackAction<SaveIntent>(
                onInvoke: (SaveIntent intent) async =>
                    await saveFile(context, appModel),
              ),
              EscapeIntent: CallbackAction<EscapeIntent>(
                onInvoke: (EscapeIntent intent) async {
                  appModel.selector.isVisible = false;
                  appModel.update();
                  return null;
                },
              ),
              DeleteIntent: CallbackAction<DeleteIntent>(
                onInvoke: (DeleteIntent intent) async {
                  // TODO
                  appModel.update();
                  return null;
                },
              ),
            },
            child: const Focus(
              // Ensure the widget can receive keyboard focus
              autofocus: true, // Automatically request focus
              child: MainScreen(),
            ),
          ),
        ),
      ),
    );
  }
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}
