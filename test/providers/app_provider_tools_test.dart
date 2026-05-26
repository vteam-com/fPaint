import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/app_provider_tools.dart';

const ui.Rect _selectionRect = ui.Rect.fromLTWH(1, 1, 3, 3);

void main() {
  group('isFloodFillOriginModifierPressedForPlatform', () {
    test('uses Option on Apple platforms', () {
      final bool result = isFloodFillOriginModifierPressedForPlatform(
        platform: TargetPlatform.macOS,
        isAltPressed: true,
        isControlPressed: false,
      );

      expect(result, isTrue);
    });

    test('ignores Control on Apple platforms', () {
      final bool result = isFloodFillOriginModifierPressedForPlatform(
        platform: TargetPlatform.iOS,
        isAltPressed: false,
        isControlPressed: true,
      );

      expect(result, isFalse);
    });

    test('uses Control on non-Apple platforms', () {
      final bool result = isFloodFillOriginModifierPressedForPlatform(
        platform: TargetPlatform.windows,
        isAltPressed: false,
        isControlPressed: true,
      );

      expect(result, isTrue);
    });

    test('ignores Option on non-Apple platforms', () {
      final bool result = isFloodFillOriginModifierPressedForPlatform(
        platform: TargetPlatform.linux,
        isAltPressed: true,
        isControlPressed: false,
      );

      expect(result, isFalse);
    });
  });

  group('shouldUseSelectionRegionFloodFill', () {
    test('uses the selection region when a selection is active and modifier is not pressed', () {
      final ui.Path selectionPath = ui.Path()..addRect(_selectionRect);

      final bool result = shouldUseSelectionRegionFloodFill(
        isSelectionVisible: true,
        selectionPath: selectionPath,
        isOriginFloodFillModifierPressed: false,
      );

      expect(result, isTrue);
    });

    test('does not use the selection region when no selection is active', () {
      final ui.Path selectionPath = ui.Path()..addRect(_selectionRect);

      final bool result = shouldUseSelectionRegionFloodFill(
        isSelectionVisible: false,
        selectionPath: selectionPath,
        isOriginFloodFillModifierPressed: false,
      );

      expect(result, isFalse);
    });

    test('does not use the selection region when the selection path is missing', () {
      final bool result = shouldUseSelectionRegionFloodFill(
        isSelectionVisible: true,
        selectionPath: null,
        isOriginFloodFillModifierPressed: false,
      );

      expect(result, isFalse);
    });

    test('does not use the selection region when the origin modifier is pressed', () {
      final ui.Path selectionPath = ui.Path()..addRect(_selectionRect);

      final bool result = shouldUseSelectionRegionFloodFill(
        isSelectionVisible: true,
        selectionPath: selectionPath,
        isOriginFloodFillModifierPressed: true,
      );

      expect(result, isFalse);
    });
  });
}
