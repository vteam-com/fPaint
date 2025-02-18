import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

Widget shortCutsForMainApp(
  final ShellProvider shellModel,
  final AppProvider appModel,
  final Widget child,
) {
  return Shortcuts(
    shortcuts: <ShortcutActivator, Intent>{
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
      //-------------------------------------------------
      // Save
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyS,
      ): const SaveIntent(),

      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyS,
      ): const SaveIntent(),

      //-------------------------------------------------
      // Cut
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyX,
      ): const CutIntent(),

      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyX,
      ): const CutIntent(),

      //-------------------------------------------------
      // Copy
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyC,
      ): const CopyIntent(),

      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyC,
      ): const CopyIntent(),

      //-------------------------------------------------
      // Paste
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyV,
      ): const PasteIntent(),

      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyV,
      ): const PasteIntent(),

      //-------------------------------------------------
      // Tab key
      LogicalKeySet(
        LogicalKeyboardKey.tab,
      ): const ToggleShellModeIntent(),

      //-------------------------------------------------
      // Select All
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyA,
      ): const SelectAllIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyA,
      ): const SelectAllIntent(),

      //-------------------------------------------------
      // Escape
      LogicalKeySet(
        LogicalKeyboardKey.escape,
      ): const EscapeIntent(),

      //-------------------------------------------------
      // Delete/Backspace
      LogicalKeySet(
        LogicalKeyboardKey.delete,
      ): const DeleteIntent(),

      LogicalKeySet(
        LogicalKeyboardKey.backspace,
      ): const DeleteIntent(),
    },
    child: Actions(
      actions: <Type, Action<Intent>>{
        UndoIntent: CallbackAction<UndoIntent>(
          onInvoke: (UndoIntent intent) => appModel.layersUndo(),
        ),
        RedoIntent: CallbackAction<RedoIntent>(
          onInvoke: (RedoIntent intent) => appModel.layersRedo(),
        ),
        SaveIntent: CallbackAction<SaveIntent>(
          onInvoke: (SaveIntent intent) async =>
              await saveFile(shellModel, appModel.layers),
        ),
        CutIntent: CallbackAction<CutIntent>(
          onInvoke: (CutIntent intent) async => appModel.regionCut(),
        ),
        CopyIntent: CallbackAction<CopyIntent>(
          onInvoke: (CopyIntent intent) async => await appModel.regionCopy(),
        ),
        PasteIntent: CallbackAction<PasteIntent>(
          onInvoke: (PasteIntent intent) async => await appModel.paste(),
        ),

        //-------------------------------------------------------------
        // toggle shell mode aka the tools
        ToggleShellModeIntent: CallbackAction<ToggleShellModeIntent>(
          onInvoke: (ToggleShellModeIntent intent) async {
            switch (shellModel.shellMode) {
              case ShellMode.hidden:
                shellModel.shellMode = ShellMode.full;
                break;
              default:
                shellModel.shellMode = ShellMode.hidden;
            }
            appModel.update();
            return null;
          },
        ),

        //-------------------------------------------------------------
        // Select all
        SelectAllIntent: CallbackAction<SelectAllIntent>(
          onInvoke: (SelectAllIntent intent) async {
            appModel.selectAll();
            appModel.selectedAction = ActionType.selector;
            return null;
          },
        ),

        //-------------------------------------------------------------
        // Escape current action
        EscapeIntent: CallbackAction<EscapeIntent>(
          onInvoke: (EscapeIntent intent) async {
            appModel.selector.clear();
            appModel.update();
            return null;
          },
        ),

        //-------------------------------------------------------------
        // Delete/Erase
        DeleteIntent: CallbackAction<DeleteIntent>(
          onInvoke: (DeleteIntent intent) async {
            appModel.regionErase();
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

class SelectAllIntent extends Intent {
  const SelectAllIntent();
}

class CutIntent extends Intent {
  const CutIntent();
}

class CopyIntent extends Intent {
  const CopyIntent();
}

class PasteIntent extends Intent {
  const PasteIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

class ToggleShellModeIntent extends Intent {
  const ToggleShellModeIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}
