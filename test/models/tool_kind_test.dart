import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/tool_kind.dart';

void main() {
  group('ToolKind.isSupported', () {
    test('pencil', () {
      expect(ToolKind.pencil.isSupported(ActionOptions.brushSize), isTrue);
      expect(ToolKind.pencil.isSupported(ActionOptions.brushColor), isTrue);
      expect(ToolKind.pencil.isSupported(ActionOptions.topColors), isTrue);
      expect(ToolKind.pencil.isSupported(ActionOptions.brushStyle), isFalse);
      expect(ToolKind.pencil.isSupported(ActionOptions.colorFill), isFalse);
    });

    test('brush', () {
      expect(ToolKind.brush.isSupported(ActionOptions.brushStyle), isTrue);
      expect(ToolKind.brush.isSupported(ActionOptions.tolerance), isFalse);
    });

    test('pixel brushes expose intensity but no color', () {
      for (final ToolKind tool in <ToolKind>[ToolKind.smudge, ToolKind.blurBrush]) {
        expect(tool.isSupported(ActionOptions.brushIntensity), isTrue);
        expect(tool.isSupported(ActionOptions.brushColor), isFalse);
      }
    });

    test('fill, shapes, text and selector', () {
      expect(ToolKind.fill.isSupported(ActionOptions.tolerance), isTrue);
      expect(ToolKind.fill.isSupported(ActionOptions.brushSize), isFalse);
      expect(ToolKind.circle.isSupported(ActionOptions.colorFill), isTrue);
      expect(ToolKind.text.isSupported(ActionOptions.brushColor), isTrue);
      expect(ToolKind.selector.isSupported(ActionOptions.selectorOptions), isTrue);
      expect(ToolKind.selector.isSupported(ActionOptions.brushSize), isFalse);
    });
  });

  group('ToolKind metadata', () {
    test('icons', () {
      expect(ToolKind.pencil.icon, AppIcon.create);
      expect(ToolKind.brush.icon, AppIcon.brush);
      expect(ToolKind.smudge.icon, AppIcon.smudge);
      expect(ToolKind.eraser.icon, AppIcon.eraser);
      expect(ToolKind.selector.icon, AppIcon.selector);
    });

    test('every tool but the selector records an action of the same name', () {
      for (final ToolKind tool in ToolKind.values) {
        if (tool == ToolKind.selector) {
          expect(tool.recordType, isNull);
        } else {
          expect(tool.recordType?.name, tool.name);
        }
      }
    });

    test('gesture kinds group tools that share pointer behaviour', () {
      expect(ToolKind.pencil.gesture, ToolGestureKind.polyline);
      expect(ToolKind.eraser.gesture, ToolGestureKind.polyline);
      expect(ToolKind.brush.gesture, ToolGestureKind.pressureStroke);
      for (final ToolKind tool in <ToolKind>[ToolKind.line, ToolKind.rectangle, ToolKind.circle]) {
        expect(tool.gesture, ToolGestureKind.shape);
      }
      expect(ToolKind.fill.gesture, ToolGestureKind.fill);
      expect(ToolKind.text.gesture, ToolGestureKind.text);
      expect(ToolKind.selector.gesture, ToolGestureKind.selection);
    });

    test('isPixelBrush matches the pixel-brush gesture', () {
      expect(
        ToolKind.values.where((ToolKind tool) => tool.isPixelBrush),
        <ToolKind>[ToolKind.smudge, ToolKind.blurBrush],
      );
    });

    test('label localizes every tool', () async {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(ToolKind.fill.label(l10n), l10n.toolPaintBucket);
      expect(ToolKind.selector.label(l10n), l10n.toolSelector);
      expect(ToolKind.values.map((ToolKind tool) => tool.label(l10n)).toSet(), hasLength(ToolKind.values.length));
    });
  });

  group('ToolKind.brushSizeRange', () {
    test('the pencil starts at one pixel', () {
      expect(ToolKind.pencil.brushSizeRange().min, AppMath.one.toDouble());
      expect(ToolKind.brush.brushSizeRange().min, AppInteraction.minCanvasScale);
    });

    test('pixel brushes and armed effects reach the pixel-brush maximum', () {
      final double pixelMax = AppLimits.pixelBrushSizeMax.toDouble();
      expect(ToolKind.smudge.brushSizeRange().max, pixelMax);
      expect(ToolKind.brush.brushSizeRange(effectArmed: true).max, pixelMax);
      expect(ToolKind.pencil.brushSizeRange(effectArmed: true).min, AppInteraction.minCanvasScale);
      expect(ToolKind.brush.brushSizeRange().max, AppLimits.percentMax.toDouble());
    });
  });
}
