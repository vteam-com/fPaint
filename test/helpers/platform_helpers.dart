import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';

/// Returns the appropriate modifier key based on the current platform.
/// Uses Alt on Apple platforms (macOS, iOS) and Control on others.
LogicalKeyboardKey getPlatformModifierKey() {
  final bool isApplePlatform =
      defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
  return isApplePlatform ? LogicalKeyboardKey.altLeft : LogicalKeyboardKey.controlLeft;
}
