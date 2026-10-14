import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether [platform] is an Apple platform (macOS or iOS), where the primary
/// modifier is Command and the alternate modifier is Option.
bool isApplePlatformFor(TargetPlatform platform) {
  return platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
}

/// Whether the app is running on an Apple platform (see [isApplePlatformFor]).
bool get isApplePlatform => isApplePlatformFor(defaultTargetPlatform);

/// Whether the platform's alternate-action modifier is held: Option on Apple
/// platforms, Ctrl elsewhere.
///
/// Drives duplicate-on-drag for selections and origin-based flood fill.
bool isPrimaryAltModifierPressed() {
  final HardwareKeyboard keyboard = HardwareKeyboard.instance;
  return isApplePlatform ? keyboard.isAltPressed : keyboard.isControlPressed;
}
