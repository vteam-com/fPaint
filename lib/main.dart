import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/main_screen.dart';
import 'package:provider/provider.dart';
import 'models/app_model.dart';

void main() {
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
        theme: ThemeData.dark(), // Use dark theme
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
          },
          child: Actions(
            actions: {
              UndoIntent: CallbackAction<UndoIntent>(
                onInvoke: (UndoIntent intent) => appModel.undo(),
              ),
              RedoIntent: CallbackAction<RedoIntent>(
                onInvoke: (RedoIntent intent) => appModel.redo(),
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
