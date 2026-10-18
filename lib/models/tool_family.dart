import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/models/tool_kind.dart';

/// The bare-key keyboard shortcut that selects each tool from the rail.
///
/// Derived from [kToolShortcuts], the same table that registers the bindings
/// in `shortCutsForMainApp`, so a tooltip never advertises a key that does
/// nothing. Tools absent from this map are reachable from the rail only.
final Map<ToolKind, String> kToolShortcutKeys = Map<ToolKind, String>.unmodifiable(<ToolKind, String>{
  for (final ToolShortcut shortcut in kToolShortcuts) shortcut.tool: shortcut.label,
});

/// The bare-key keyboard shortcut that selects [tool], or null when the tool
/// has no binding.
String? toolShortcutLabel(ToolKind tool) => kToolShortcutKeys[tool];

/// A bare-key keyboard binding that selects a tool.
class ToolShortcut {
  /// Creates a [ToolShortcut].
  const ToolShortcut({
    required this.tool,
    required this.key,
    required this.label,
    required this.helpAction,
  });

  /// The tool the key selects.
  final ToolKind tool;

  /// Display text of [tool] in the shortcuts help dialog.
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
    tool: ToolKind.brush,
    key: LogicalKeyboardKey.keyB,
    label: ShortcutKeys.b,
    helpAction: ShortcutActions.brushTool,
  ),
  ToolShortcut(
    tool: ToolKind.eraser,
    key: LogicalKeyboardKey.keyE,
    label: ShortcutKeys.e,
    helpAction: ShortcutActions.eraserTool,
  ),
  ToolShortcut(
    tool: ToolKind.selector,
    key: LogicalKeyboardKey.keyS,
    label: ShortcutKeys.s,
    helpAction: ShortcutActions.selectionTool,
  ),
  ToolShortcut(
    tool: ToolKind.fill,
    key: LogicalKeyboardKey.keyF,
    label: ShortcutKeys.f,
    helpAction: ShortcutActions.fillTool,
  ),
  ToolShortcut(
    tool: ToolKind.text,
    key: LogicalKeyboardKey.keyT,
    label: ShortcutKeys.t,
    helpAction: ShortcutActions.textTool,
  ),
];
