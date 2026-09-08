import 'package:flutter/foundation.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';

const String _tooltipShortcutOpen = ' (';
const String _tooltipShortcutClose = ')';

/// Appends a shortcut label to a tooltip when both are available.
String? tooltipWithShortcut(
  String? tooltip,
  String? shortcut,
) {
  if (tooltip == null || tooltip.isEmpty || shortcut == null || shortcut.isEmpty) {
    return tooltip;
  }

  return '$tooltip$_tooltipShortcutOpen$shortcut$_tooltipShortcutClose';
}

/// Returns the platform primary modifier label (Command glyph on Apple platforms, Ctrl elsewhere).
String primaryModifierShortcutLabel() {
  return _isApplePlatform ? ShortcutModifiers.cmd : ShortcutModifiers.ctrl;
}

/// Returns the platform control modifier label (Control glyph on Apple platforms, Ctrl elsewhere).
String controlModifierShortcutLabel() {
  return _isApplePlatform ? ShortcutModifiers.ctrlSymbol : ShortcutModifiers.ctrl;
}

/// Returns the label for the duplicate-on-drag modifier
/// (Option glyph on Apple platforms, Ctrl elsewhere — see `_shouldDuplicateMoveGesture`).
String duplicateDragModifierShortcutLabel() {
  return _isApplePlatform ? ShortcutModifiers.option : ShortcutModifiers.ctrl;
}

/// Returns the platform secondary modifier label (Option glyph on Apple platforms, Alt elsewhere).
String secondaryModifierShortcutLabel() {
  return _isApplePlatform ? ShortcutModifiers.option : ShortcutModifiers.alt;
}

/// Returns the platform shift modifier label (Shift glyph on Apple platforms, Shift elsewhere).
String shiftModifierShortcutLabel() {
  return _isApplePlatform ? ShortcutModifiers.shiftSymbol : ShortcutModifiers.shift;
}

/// Joins modifier and key labels with the shortcut separator, skipping empty parts.
String shortcutCombination(List<String> parts) {
  return parts.where((String part) => part.isNotEmpty).join(ShortcutModifiers.separator);
}

/// Returns a shortcut label for a primary-modifier + key combination.
String primaryModifiedShortcut(String key) {
  return shortcutCombination(<String>[primaryModifierShortcutLabel(), key]);
}

/// Returns a shortcut label for a plain single key.
String singleKeyShortcut(String key) {
  return key;
}

bool get _isApplePlatform {
  return defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
}
