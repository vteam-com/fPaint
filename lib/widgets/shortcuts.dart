import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/shortcuts_help.dart';

/// Wraps the given [child] widget with [Shortcuts] and [Actions] to provide keyboard shortcuts for the main application.
///
/// This function sets up keyboard shortcuts for common actions like undo, redo, save, cut, copy, paste, and more.
/// It also provides actions that are triggered when these shortcuts are activated.
///
/// The [context] parameter is the [BuildContext] used to access the application's providers.
/// The [shellProvider] parameter is the [ShellProvider] instance used to manage the application's shell.
/// The [appProvider] parameter is the [AppProvider] instance used to manage the application's state.
/// The [child] parameter is the widget to wrap with the keyboard shortcuts and actions.
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

      // Add a help shortcut
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.slash):
          const HelpIntent(),
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

        // Add a help action
        HelpIntent: CallbackAction<HelpIntent>(
          onInvoke: (final HelpIntent intent) {
            showShortcutsHelp(context);
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

/// An [Intent] that triggers the undo action.
class UndoIntent extends Intent {
  /// Creates an [UndoIntent].
  const UndoIntent();
}

/// An [Intent] that triggers the redo action.
class RedoIntent extends Intent {
  /// Creates a [RedoIntent].
  const RedoIntent();
}

/// An [Intent] that triggers the save action.
class SaveIntent extends Intent {
  /// Creates a [SaveIntent].
  const SaveIntent();
}

/// An [Intent] that triggers the select all action.
class SelectAllIntent extends Intent {
  /// Creates a [SelectAllIntent].
  const SelectAllIntent();
}

/// An [Intent] that triggers the new document from clipboard image action.
class NewDocumentFromClipboardImage extends Intent {
  /// Creates a [NewDocumentFromClipboardImage].
  const NewDocumentFromClipboardImage();
}

/// An [Intent] that triggers the cut action.
class CutIntent extends Intent {
  /// Creates a [CutIntent].
  const CutIntent();
}

/// An [Intent] that triggers the copy action.
class CopyIntent extends Intent {
  /// Creates a [CopyIntent].
  const CopyIntent();
}

/// An [Intent] that triggers the paste action.
class PasteIntent extends Intent {
  /// Creates a [PasteIntent].
  const PasteIntent();
}

/// An [Intent] that triggers the escape action.
class EscapeIntent extends Intent {
  /// Creates an [EscapeIntent].
  const EscapeIntent();
}

/// An [Intent] that triggers the toggle shell mode action.
class ToggleShellModeIntent extends Intent {
  /// Creates a [ToggleShellModeIntent].
  const ToggleShellModeIntent();
}

/// An [Intent] that triggers the delete action.
class DeleteIntent extends Intent {
  /// Creates a [DeleteIntent].
  const DeleteIntent();
}

/// An [Intent] that triggers the help action.
class HelpIntent extends Intent {
  /// Creates a [HelpIntent].
  const HelpIntent();
}

// Add a method to show the shortcuts help dialog
void showShortcutsHelp(final BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (final BuildContext context) => const ShortcutsHelpDialog(),
  );
}
