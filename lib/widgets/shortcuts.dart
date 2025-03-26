import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

Widget shortCutsForMainApp(
  final BuildContext context,
  final ShellProvider shellProvider,
  final AppProvider appProvider,
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
      // New document from Clipboard
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyN,
      ): const NewDocumentFromClipboardImage(),

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
          onInvoke: (final UndoIntent intent) => appProvider.undoAction(),
        ),
        RedoIntent: CallbackAction<RedoIntent>(
          onInvoke: (final RedoIntent intent) => appProvider.redoAction(),
        ),
        SaveIntent: CallbackAction<SaveIntent>(
          onInvoke: (final SaveIntent intent) async =>
              await saveFile(shellProvider, appProvider.layers),
        ),
        CutIntent: CallbackAction<CutIntent>(
          onInvoke: (final CutIntent intent) async => appProvider.regionCut(),
        ),
        CopyIntent: CallbackAction<CopyIntent>(
          onInvoke: (final CopyIntent intent) async =>
              await appProvider.regionCopy(),
        ),
        NewDocumentFromClipboardImage:
            CallbackAction<NewDocumentFromClipboardImage>(
          onInvoke: (final NewDocumentFromClipboardImage intent) async {
            if (appProvider.layers.hasChanged &&
                await confirmDiscardCurrentWork(context) == false) {
              return;
            }
            appProvider.newDocumentFromClipboardImage();
            return null;
          },
        ),
        PasteIntent: CallbackAction<PasteIntent>(
          onInvoke: (final PasteIntent intent) async =>
              await appProvider.paste(),
        ),

        //-------------------------------------------------------------
        // toggle shell mode aka the tools
        ToggleShellModeIntent: CallbackAction<ToggleShellModeIntent>(
          onInvoke: (final ToggleShellModeIntent intent) async {
            switch (shellProvider.shellMode) {
              case ShellMode.hidden:
                shellProvider.shellMode = ShellMode.full;
                break;
              default:
                shellProvider.shellMode = ShellMode.hidden;
            }
            appProvider.update();
            return null;
          },
        ),

        //-------------------------------------------------------------
        // Select all
        SelectAllIntent: CallbackAction<SelectAllIntent>(
          onInvoke: (final SelectAllIntent intent) async {
            appProvider.selectAll();
            appProvider.selectedAction = ActionType.selector;
            return null;
          },
        ),

        //-------------------------------------------------------------
        // Escape current action
        EscapeIntent: CallbackAction<EscapeIntent>(
          onInvoke: (final EscapeIntent intent) async {
            appProvider.selectorModel.clear();
            appProvider.fillModel.clear();
            appProvider.eyeDropPositionForBrush = null;
            appProvider.eyeDropPositionForFill = null;
            appProvider.update();
            return null;
          },
        ),

        //-------------------------------------------------------------
        // Delete/Erase
        DeleteIntent: CallbackAction<DeleteIntent>(
          onInvoke: (final DeleteIntent intent) async {
            appProvider.regionErase();
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

class NewDocumentFromClipboardImage extends Intent {
  const NewDocumentFromClipboardImage();
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
