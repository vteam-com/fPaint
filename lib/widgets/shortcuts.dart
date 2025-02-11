import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/models/app_model.dart';

Widget shortCutsForMainApp(final AppModel appModel, final Widget child) {
  return Shortcuts(
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

      LogicalKeySet(
        LogicalKeyboardKey.backspace,
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
          onInvoke: (SaveIntent intent) async => await saveFile(appModel),
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
            appModel.deleteSelectedRegion();
            return null;
          },
        ),
      },
      child: Focus(
        // Ensure the widget can receive keyboard focus
        autofocus: true, // Automatically request focus
        child: child,
      ),
    ),
  );
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
