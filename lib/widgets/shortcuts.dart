// ignore: fcheck_one_class_per_file
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/locked_layer_guard.dart';
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
/// [onSave] and [onNewFromClipboard] run the document Save and guarded
/// "New from clipboard" flows, which live above the widget layer.
Widget shortCutsForMainApp(
  BuildContext context,
  ShellProvider shellProvider,
  AppProvider appProvider,
  Widget child, {
  required Future<void> Function() onSave,
  required Future<void> Function() onNewFromClipboard,
}) {
  final Map<ShortcutActivator, Intent> shortcuts = _buildShortcuts();

  /// Keyboard zoom/rotate take over from auto-placement and pivot on the
  /// canvas centre, since there is no pointer to anchor to.
  Object? zoomAboutCenter(double scaleDelta) {
    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.zoomAboutCenter(scaleDelta);
    return null;
  }

  Object? rotateAboutCenter(double rotationDelta) {
    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.rotateAboutCenter(rotationDelta);
    return null;
  }

  return _MainAppShortcutScope(
    appProvider: appProvider,
    shortcuts: shortcuts,
    actions: <Type, Action<Intent>>{
      UndoIntent: CallbackAction<UndoIntent>(
        onInvoke: (UndoIntent _) => appProvider.undoAction(),
      ),
      RedoIntent: CallbackAction<RedoIntent>(
        onInvoke: (RedoIntent _) => appProvider.redoAction(),
      ),
      ZoomInIntent: CallbackAction<ZoomInIntent>(
        onInvoke: (ZoomInIntent _) => zoomAboutCenter(AppVisual.enlarge),
      ),
      ZoomOutIntent: CallbackAction<ZoomOutIntent>(
        onInvoke: (ZoomOutIntent _) => zoomAboutCenter(AppVisual.shrink),
      ),
      ResetZoomIntent: CallbackAction<ResetZoomIntent>(
        onInvoke: (ResetZoomIntent _) {
          // Same path as the zoom-value button: the fit needs the laid-out
          // viewport size, so request the placement rather than computing a
          // scale here.
          shellProvider.requestCanvasFitAndRepaint(appProvider.repaintViewport);
          return null;
        },
      ),
      RotateViewCounterClockwiseIntent: CallbackAction<RotateViewCounterClockwiseIntent>(
        onInvoke: (RotateViewCounterClockwiseIntent _) =>
            rotateAboutCenter(-degreesToRadians(AppInteraction.viewportRotationKeyboardStepDegrees)),
      ),
      RotateViewClockwiseIntent: CallbackAction<RotateViewClockwiseIntent>(
        onInvoke: (RotateViewClockwiseIntent _) =>
            rotateAboutCenter(degreesToRadians(AppInteraction.viewportRotationKeyboardStepDegrees)),
      ),
      BrushSizeDecreaseIntent: CallbackAction<BrushSizeDecreaseIntent>(
        onInvoke: (BrushSizeDecreaseIntent _) => appProvider.stepBrushSize(increase: false),
      ),
      BrushSizeIncreaseIntent: CallbackAction<BrushSizeIncreaseIntent>(
        onInvoke: (BrushSizeIncreaseIntent _) => appProvider.stepBrushSize(increase: true),
      ),
      SaveIntent: CallbackAction<SaveIntent>(
        onInvoke: (SaveIntent _) async => await onSave(),
      ),
      CutIntent: CallbackAction<CutIntent>(
        onInvoke: (CutIntent _) async {
          if (!guardSelectedLayerUnlocked(context, appProvider)) {
            return null;
          }

          await appProvider.regionCut();
          return null;
        },
      ),
      CopyIntent: CallbackAction<CopyIntent>(
        onInvoke: (CopyIntent _) async => await appProvider.regionCopy(),
      ),
      NewDocumentFromClipboardImage: CallbackAction<NewDocumentFromClipboardImage>(
        onInvoke: (NewDocumentFromClipboardImage _) async {
          await onNewFromClipboard();
          return null;
        },
      ),
      PasteIntent: CallbackAction<PasteIntent>(
        onInvoke: (PasteIntent _) async => await appProvider.paste(),
      ),
      DuplicateIntent: CallbackAction<DuplicateIntent>(
        onInvoke: (DuplicateIntent _) async {
          if (!guardSelectedLayerUnlocked(context, appProvider)) {
            return null;
          }

          await appProvider.regionDuplicateSameLayer();
          return null;
        },
      ),
      DuplicateNewLayerIntent: CallbackAction<DuplicateNewLayerIntent>(
        onInvoke: (DuplicateNewLayerIntent _) async => await appProvider.regionDuplicate(),
      ),

      //-------------------------------------------------------------
      // toggle shell mode aka the tools
      ToggleShellModeIntent: CallbackAction<ToggleShellModeIntent>(
        onInvoke: (ToggleShellModeIntent _) async {
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
        onInvoke: (SelectAllIntent _) async {
          appProvider.selectAll();
          appProvider.activateSelectionAction();
          return null;
        },
      ),

      SelectToolIntent: CallbackAction<SelectToolIntent>(
        onInvoke: (SelectToolIntent intent) {
          appProvider.selectedTool = intent.tool;
          return null;
        },
      ),

      //-------------------------------------------------------------
      // Escape current action
      EscapeIntent: CallbackAction<EscapeIntent>(
        onInvoke: (EscapeIntent _) async {
          // An open quick menu is the innermost thing to back out of.
          if (appProvider.quickMenuModel.isOpen) {
            appProvider.quickMenuModel.close();
            return null;
          }
          // Discard any live gradient-fill session before restoring the tool, so
          // Escape backs out of the fill (no undo entry) rather than applying it.
          appProvider.cancelGradientPreview();
          appProvider.clearSelectionAndRestorePreviousTool();
          appProvider.deactivateEyeDropShortcut();
          appProvider.update();
          return null;
        },
      ),

      //-------------------------------------------------------------
      // Delete/Erase
      DeleteIntent: CallbackAction<DeleteIntent>(
        onInvoke: (DeleteIntent _) async {
          if (appProvider.selectorModel.path1 != null && !guardSelectedLayerUnlocked(context, appProvider)) {
            return null;
          }

          appProvider.regionErase();
          return null;
        },
      ),

      // Add a help action
      HelpIntent: CallbackAction<HelpIntent>(
        onInvoke: (HelpIntent _) {
          showShortcutsHelp(context);
          return null;
        },
      ),
    },
    child: child,
  );
}

class _MainAppShortcutScope extends StatefulWidget {
  const _MainAppShortcutScope({
    required this.appProvider,
    required this.shortcuts,
    required this.actions,
    required this.child,
  });
  final Map<Type, Action<Intent>> actions;
  final AppProvider appProvider;
  final Widget child;
  final Map<ShortcutActivator, Intent> shortcuts;
  @override
  State<_MainAppShortcutScope> createState() => _MainAppShortcutScopeState();
}

class _MainAppShortcutScopeState extends State<_MainAppShortcutScope> {
  late final FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent _) {
        _restoreShortcutFocus();
      },
      child: Shortcuts(
        shortcuts: widget.shortcuts,
        child: Actions(
          actions: widget.actions,
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  /// Handles keyboard events for modifier keys such as Alt / Option eyedropper shortcut.
  bool _handleKeyEvent(KeyEvent event) {
    final bool isAltKey =
        event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight ||
        event.logicalKey == LogicalKeyboardKey.alt;

    final AppProvider appProvider = widget.appProvider;

    final FocusNode? primaryFocus = FocusManager.instance.primaryFocus;
    final bool isTextEditingFocused =
        primaryFocus != null &&
        primaryFocus.context != null &&
        primaryFocus.context!.findAncestorWidgetOfExactType<EditableText>() != null;

    if (isTextEditingFocused) {
      if (appProvider.isEyeDropShortcutActive) {
        appProvider.deactivateEyeDropShortcut();
      }
      return false;
    }

    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isAltPressed = keyboard.isAltPressed;
    final bool isControlOrMetaPressed = keyboard.isControlPressed || keyboard.isMetaPressed;

    if (event is KeyDownEvent && isAltKey && !isControlOrMetaPressed) {
      if (!appProvider.isEyeDropShortcutActive && isAltPressed) {
        appProvider.activateEyeDropShortcut();
      }
    } else if (appProvider.isEyeDropShortcutActive && (!isAltPressed || isControlOrMetaPressed)) {
      // Releasing Alt ends the shortcut — and so does *adding* Ctrl/Cmd, which
      // escalates the chord into the brush-resize gesture (Cmd+Opt / Ctrl+Alt).
      // Without the second test, pressing Option before Cmd would leave the
      // eyedropper armed and it would swallow the resize drag.
      appProvider.deactivateEyeDropShortcut();
    }

    return false;
  }

  void _restoreShortcutFocus() {
    if (_focusNode.hasFocus) {
      return;
    }
    _focusNode.requestFocus();
  }
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

/// An [Intent] that triggers zoom in.
class ZoomInIntent extends Intent {
  /// Creates a [ZoomInIntent].
  const ZoomInIntent();
}

/// An [Intent] that triggers zoom out.
class ZoomOutIntent extends Intent {
  /// Creates a [ZoomOutIntent].
  const ZoomOutIntent();
}

/// An [Intent] that resets zoom to 100%.
class ResetZoomIntent extends Intent {
  /// Creates a [ResetZoomIntent].
  const ResetZoomIntent();
}

/// An [Intent] that rotates the canvas view counter-clockwise by one nudge.
class RotateViewCounterClockwiseIntent extends Intent {
  /// Creates a [RotateViewCounterClockwiseIntent].
  const RotateViewCounterClockwiseIntent();
}

/// An [Intent] that rotates the canvas view clockwise by one nudge.
class RotateViewClockwiseIntent extends Intent {
  /// Creates a [RotateViewClockwiseIntent].
  const RotateViewClockwiseIntent();
}

/// An [Intent] that shrinks the armed tool's brush by one keyboard step.
class BrushSizeDecreaseIntent extends Intent {
  /// Creates a [BrushSizeDecreaseIntent].
  const BrushSizeDecreaseIntent();
}

/// An [Intent] that grows the armed tool's brush by one keyboard step.
class BrushSizeIncreaseIntent extends Intent {
  /// Creates a [BrushSizeIncreaseIntent].
  const BrushSizeIncreaseIntent();
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

/// An [Intent] that switches to [tool] (see [kToolShortcuts]).
class SelectToolIntent extends Intent {
  /// Creates a [SelectToolIntent] for [tool].
  const SelectToolIntent(this.tool);

  /// The tool to activate.
  final ToolKind tool;
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
void showShortcutsHelp(BuildContext context) {
  showAppDialog<void>(
    context: context,
    builder: (BuildContext _) => const ShortcutsHelpDialog(),
  );
}

/// Binds [intent] to exactly Cmd + [key] and exactly Ctrl + [key] (plus Shift
/// when [shift] is true), so one call covers macOS and Windows/Linux.
void addPrimaryModifierShortcut(
  Map<ShortcutActivator, Intent> shortcuts,
  LogicalKeyboardKey key,
  Intent intent, {
  bool shift = false,
}) {
  shortcuts[SingleActivator(key, meta: true, shift: shift)] = intent;
  shortcuts[SingleActivator(key, control: true, shift: shift)] = intent;
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

  // Undo / Redo
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.keyZ, const UndoIntent());
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.keyZ, const RedoIntent(), shift: true);
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.keyY, const RedoIntent());

  // Zoom in (Cmd/Ctrl + '=' and Cmd/Ctrl + Shift + '=' for '+').
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.equal, const ZoomInIntent());
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.equal, const ZoomInIntent(), shift: true);
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.numpadAdd, const ZoomInIntent());

  // Zoom out (Cmd/Ctrl + '-').
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.minus, const ZoomOutIntent());
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.numpadSubtract, const ZoomOutIntent());

  // Brush size: bare `[` / `]`, the convention every major paint app shares.
  shortcuts[const SingleActivator(LogicalKeyboardKey.bracketLeft)] = const BrushSizeDecreaseIntent();
  shortcuts[const SingleActivator(LogicalKeyboardKey.bracketRight)] = const BrushSizeIncreaseIntent();

  // View rotation: Krita's modifier-free `4` / `6` nudge, on both the top-row
  // digits and the numeric keypad. Reset stays folded into the Cmd/Ctrl+0 fit.
  shortcuts[const SingleActivator(LogicalKeyboardKey.digit4)] = const RotateViewCounterClockwiseIntent();
  shortcuts[const SingleActivator(LogicalKeyboardKey.numpad4)] = const RotateViewCounterClockwiseIntent();
  shortcuts[const SingleActivator(LogicalKeyboardKey.digit6)] = const RotateViewClockwiseIntent();
  shortcuts[const SingleActivator(LogicalKeyboardKey.numpad6)] = const RotateViewClockwiseIntent();

  // Reset zoom (Cmd/Ctrl + '0').
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.digit0, const ResetZoomIntent());
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.numpad0, const ResetZoomIntent());

  // Save
  addCrossPlatformShortcut(LogicalKeyboardKey.keyS, const SaveIntent());

  // Cut
  addCrossPlatformShortcut(LogicalKeyboardKey.keyX, const CutIntent());

  // Copy
  addCrossPlatformShortcut(LogicalKeyboardKey.keyC, const CopyIntent());

  // Paste
  addCrossPlatformShortcut(LogicalKeyboardKey.keyV, const PasteIntent());

  // Duplicate in the selected layer (exactly Cmd/Ctrl + D).
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.keyD, const DuplicateIntent());

  // Duplicate to a new layer (exactly Shift + Cmd/Ctrl + D).
  addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.keyD, const DuplicateNewLayerIntent(), shift: true);

  // Select All
  addCrossPlatformShortcut(LogicalKeyboardKey.keyA, const SelectAllIntent());

  // Tools (bare keys, from the shared tool-shortcut table)
  for (final ToolShortcut tool in kToolShortcuts) {
    shortcuts[SingleActivator(tool.key)] = SelectToolIntent(tool.tool);
  }

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
