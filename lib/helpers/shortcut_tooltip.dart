import 'package:flutter/foundation.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';

const String _tooltipShortcutOpen = ' (';
const String _tooltipShortcutClose = ')';
const String _shortcutKeySeparator = ' ';

/// Appends a shortcut label to a tooltip when both are available.
String? tooltipWithShortcut(
  final String? tooltip,
  final String? shortcut,
) {
  if (tooltip == null || tooltip.isEmpty || shortcut == null || shortcut.isEmpty) {
    return tooltip;
  }

  return '$tooltip$_tooltipShortcutOpen$shortcut$_tooltipShortcutClose';
}

/// Returns the platform primary modifier label (Cmd on Apple platforms, Ctrl elsewhere).
String primaryModifierShortcutLabel() {
  return _isApplePlatform ? ShortcutModifiers.cmd : ShortcutModifiers.ctrl;
}

/// Returns a shortcut label for a primary-modifier + key combination.
String primaryModifiedShortcut(final String key) {
  return '${primaryModifierShortcutLabel()}$_shortcutKeySeparator$key';
}

/// Returns a shortcut label for a plain single key.
String singleKeyShortcut(final String key) {
  return key;
}

bool get _isApplePlatform {
  return defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
}
