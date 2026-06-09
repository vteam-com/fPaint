// ignore: fcheck_one_class_per_file
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/confirm_discard_dialog.dart';
import 'package:fpaint/widgets/material_free.dart';
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
  final Widget child, {
  required final Future<void> Function() onSave,
}) {
  void showLockedLayerMessage() {
    context.showSnackBarMessage(
      context.l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
    );
  }

  final Map<ShortcutActivator, Intent> shortcuts = _buildShortcuts();

  return Shortcuts(
    shortcuts: shortcuts,
    child: Actions(
      actions: <Type, Action<Intent>>{
        UndoIntent: CallbackAction<UndoIntent>(
          onInvoke: (final UndoIntent _) => appProvider.undoAction(),
        ),
        RedoIntent: CallbackAction<RedoIntent>(
          onInvoke: (final RedoIntent _) => appProvider.redoAction(),
        ),
        SaveIntent: CallbackAction<SaveIntent>(
          onInvoke: (final SaveIntent _) async => await onSave(),
        ),
        CutIntent: CallbackAction<CutIntent>(
          onInvoke: (final CutIntent _) async {
            if (appProvider.isSelectedLayerLocked) {
              showLockedLayerMessage();
              return null;
            }

            await appProvider.regionCut();
            return null;
          },
        ),
        CopyIntent: CallbackAction<CopyIntent>(
          onInvoke: (final CopyIntent _) async => await appProvider.regionCopy(),
        ),
        NewDocumentFromClipboardImage: CallbackAction<NewDocumentFromClipboardImage>(
          onInvoke: (final NewDocumentFromClipboardImage _) async {
            if (appProvider.layers.hasChanged && await confirmDiscardCurrentWork(context) == false) {
              return;
            }
            appProvider.newDocumentFromClipboardImage();
            return null;
          },
        ),
        PasteIntent: CallbackAction<PasteIntent>(
          onInvoke: (final PasteIntent _) async => await appProvider.paste(),
        ),
        DuplicateIntent: CallbackAction<DuplicateIntent>(
          onInvoke: (final DuplicateIntent _) async {
            if (appProvider.isSelectedLayerLocked) {
              showLockedLayerMessage();
              return null;
            }

            await appProvider.regionDuplicateSameLayer();
            return null;
          },
        ),
        DuplicateNewLayerIntent: CallbackAction<DuplicateNewLayerIntent>(
          onInvoke: (final DuplicateNewLayerIntent _) async => await appProvider.regionDuplicate(),
        ),

        //-------------------------------------------------------------
        // toggle shell mode aka the tools
        ToggleShellModeIntent: CallbackAction<ToggleShellModeIntent>(
          onInvoke: (final ToggleShellModeIntent _) async {
            switch (shellProvider.shellMode) {
              case ShellMode.hidden:
                shellProvider.shellMode = ShellMode.full;
                break;
              default:
                shellProvider.shellMode = ShellMode.hidden;
            }
            return null;
          },
        ),

        //-------------------------------------------------------------
        // Select all
        SelectAllIntent: CallbackAction<SelectAllIntent>(
          onInvoke: (final SelectAllIntent _) async {
            appProvider.selectAll();
            appProvider.activateSelectionAction();
            return null;
          },
        ),

        //-------------------------------------------------------------
        // Escape current action
        EscapeIntent: CallbackAction<EscapeIntent>(
          onInvoke: (final EscapeIntent _) async {
            appProvider.clearSelectionAndRestorePreviousTool();
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
          onInvoke: (final DeleteIntent _) async {
            if (appProvider.isSelectedLayerLocked && appProvider.selectorModel.path1 != null) {
              showLockedLayerMessage();
              return null;
            }

            appProvider.regionErase();
            return null;
          },
        ),

        // Add a help action
        HelpIntent: CallbackAction<HelpIntent>(
          onInvoke: (final HelpIntent _) {
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

/// An [Intent] that triggers the duplicate action.
class DuplicateIntent extends Intent {
  /// Creates a [DuplicateIntent].
  const DuplicateIntent();
}

/// An [Intent] that triggers the duplicate-to-new-layer action.
class DuplicateNewLayerIntent extends Intent {
  /// Creates a [DuplicateNewLayerIntent].
  const DuplicateNewLayerIntent();
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

/// Shows the keyboard shortcuts help dialog.
void showShortcutsHelp(final BuildContext context) {
  showAppDialog<void>(
    context: context,
    builder: (final BuildContext _) => const ShortcutsHelpDialog(),
  );
}

/// Builds the keyboard shortcuts map, combining platform-specific shortcuts.
Map<ShortcutActivator, Intent> _buildShortcuts() {
  final Map<ShortcutActivator, Intent> shortcuts = <ShortcutActivator, Intent>{};

  // Helper function to add cross-platform shortcuts
  void addCrossPlatformShortcut(
    LogicalKeyboardKey primaryKey,
    Intent intent, {
    LogicalKeyboardKey? secondaryKey,
  }) {
    // Add Control/Cmd + primary
    shortcuts[LogicalKeySet(LogicalKeyboardKey.control, primaryKey)] = intent;
    shortcuts[LogicalKeySet(LogicalKeyboardKey.meta, primaryKey)] = intent;

    // Add Control/Cmd + secondary + primary if secondary is provided
    if (secondaryKey != null) {
      shortcuts[LogicalKeySet(LogicalKeyboardKey.control, primaryKey, secondaryKey)] = intent;
      shortcuts[LogicalKeySet(LogicalKeyboardKey.meta, primaryKey, secondaryKey)] = intent;
    }
  }

  // Undo
  addCrossPlatformShortcut(LogicalKeyboardKey.keyZ, const UndoIntent());

  // Redo
  addCrossPlatformShortcut(
    LogicalKeyboardKey.keyZ,
    const RedoIntent(),
    secondaryKey: LogicalKeyboardKey.shift,
  );

  // Save
  addCrossPlatformShortcut(LogicalKeyboardKey.keyS, const SaveIntent());

  // Cut
  addCrossPlatformShortcut(LogicalKeyboardKey.keyX, const CutIntent());

  // Copy
  addCrossPlatformShortcut(LogicalKeyboardKey.keyC, const CopyIntent());

  // Paste
  addCrossPlatformShortcut(LogicalKeyboardKey.keyV, const PasteIntent());

  // Duplicate in the selected layer (exactly Cmd/Ctrl + D).
  shortcuts[const SingleActivator(LogicalKeyboardKey.keyD, control: true)] = const DuplicateIntent();
  shortcuts[const SingleActivator(LogicalKeyboardKey.keyD, meta: true)] = const DuplicateIntent();

  // Duplicate to a new layer (exactly Shift + Cmd/Ctrl + D).
  shortcuts[const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true)] =
      const DuplicateNewLayerIntent();
  shortcuts[const SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true)] = const DuplicateNewLayerIntent();

  // Select All
  addCrossPlatformShortcut(LogicalKeyboardKey.keyA, const SelectAllIntent());

  // Tab key (no duplicates needed)
  shortcuts[LogicalKeySet(LogicalKeyboardKey.tab)] = const ToggleShellModeIntent();

  // New document from Clipboard (only Meta)
  shortcuts[LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN)] = const NewDocumentFromClipboardImage();

  // Escape
  shortcuts[LogicalKeySet(LogicalKeyboardKey.escape)] = const EscapeIntent();

  // Delete/Backspace (no duplicates needed)
  shortcuts[LogicalKeySet(LogicalKeyboardKey.delete)] = const DeleteIntent();
  shortcuts[LogicalKeySet(LogicalKeyboardKey.backspace)] = const DeleteIntent();

  // Help
  shortcuts[LogicalKeySet(LogicalKeyboardKey.f1)] = const HelpIntent();
  shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.slash)] = const HelpIntent();

  return shortcuts;
}
