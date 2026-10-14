import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/user_action_drawing.dart';

/// Localized label for a gesture tool [action] shown in the tool rail.
///
/// Gesture tools and effects share one Brush section in the rail, so there is
/// no separate "brush mode" vs. "effect mode"; a tool is a gesture when it
/// carries an [ActionType] and an effect otherwise.
String toolLabel(AppLocalizations l10n, ActionType action) {
  switch (action) {
    case ActionType.pencil:
      return l10n.toolPencil;
    case ActionType.brush:
      return l10n.toolBrush;
    case ActionType.smudge:
      return l10n.toolSmudge;
    case ActionType.blurBrush:
      return l10n.toolBlurBrush;
    case ActionType.line:
      return l10n.toolLine;
    case ActionType.rectangle:
      return l10n.toolRectangle;
    case ActionType.circle:
      return l10n.toolCircle;
    case ActionType.fill:
      return l10n.toolPaintBucket;
    case ActionType.eraser:
      return l10n.toolEraser;
    case ActionType.text:
      return l10n.toolText;
    // Actions that never appear in the tool rail.
    case ActionType.region:
    case ActionType.image:
    case ActionType.cut:
    case ActionType.selector:
      return action.name;
  }
}

/// Inclusive brush-size bounds of a tool's size slider.
typedef BrushSizeRange = ({double min, double max});

/// The brush-size range [action] accepts, matching its side-panel slider.
///
/// The smudge/blur pixel brushes and an armed effect brush ([effectArmed])
/// work at much larger radii than the paint tools; the pencil starts at one
/// pixel. An armed effect brush overrides the underlying tool's range.
BrushSizeRange brushSizeRangeFor(ActionType action, {bool effectArmed = false}) {
  final bool isPixelBrush = effectArmed || action == ActionType.smudge || action == ActionType.blurBrush;
  final bool isPencil = action == ActionType.pencil && !effectArmed;
  return (
    min: isPencil ? AppMath.one.toDouble() : AppInteraction.minCanvasScale,
    max: isPixelBrush ? AppLimits.pixelBrushSizeMax.toDouble() : AppLimits.percentMax.toDouble(),
  );
}

/// The bare-key keyboard shortcut that selects each tool from the rail.
///
/// Derived from [kToolShortcuts], the same table that registers the bindings
/// in `shortCutsForMainApp`, so a tooltip never advertises a key that does
/// nothing. Tools absent from this map are reachable from the rail only.
final Map<ActionType, String> kToolShortcutKeys = Map<ActionType, String>.unmodifiable(<ActionType, String>{
  for (final ToolShortcut shortcut in kToolShortcuts) shortcut.action: shortcut.label,
});

/// The bare-key keyboard shortcut that selects [action], or null when the tool
/// has no binding.
String? toolShortcutLabel(ActionType action) => kToolShortcutKeys[action];

/// A bare-key keyboard binding that selects a tool.
class ToolShortcut {
  /// Creates a [ToolShortcut].
  const ToolShortcut({
    required this.action,
    required this.key,
    required this.label,
    required this.helpAction,
  });

  /// The tool the key selects.
  final ActionType action;

  /// Display text of [action] in the shortcuts help dialog.
  final String helpAction;

  /// The physical binding registered with the shortcut manager.
  final LogicalKeyboardKey key;

  /// Display text of [key] in tooltips and the shortcuts help dialog.
  final String label;
}

/// The single source of truth for the bare-key tool shortcuts: the keyboard
/// bindings, the tool-rail / quick-menu tooltips and the shortcuts help dialog
/// are all generated from this table so they cannot drift apart.
const List<ToolShortcut> kToolShortcuts = <ToolShortcut>[
  ToolShortcut(
    action: ActionType.brush,
    key: LogicalKeyboardKey.keyB,
    label: ShortcutKeys.b,
    helpAction: ShortcutActions.brushTool,
  ),
  ToolShortcut(
    action: ActionType.eraser,
    key: LogicalKeyboardKey.keyE,
    label: ShortcutKeys.e,
    helpAction: ShortcutActions.eraserTool,
  ),
  ToolShortcut(
    action: ActionType.selector,
    key: LogicalKeyboardKey.keyS,
    label: ShortcutKeys.s,
    helpAction: ShortcutActions.selectionTool,
  ),
  ToolShortcut(
    action: ActionType.fill,
    key: LogicalKeyboardKey.keyF,
    label: ShortcutKeys.f,
    helpAction: ShortcutActions.fillTool,
  ),
  ToolShortcut(
    action: ActionType.text,
    key: LogicalKeyboardKey.keyT,
    label: ShortcutKeys.t,
    helpAction: ShortcutActions.textTool,
  ),
];
