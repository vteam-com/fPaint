import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layer_provider.dart';

const int _canvas = 8;
const Size _size = Size(8, 8);

LayerProvider _layer() => LayerProvider(name: 'L', size: _size, onThumbnailChanged: () {});

Future<ui.Image> _solid(final Color color) {
  return renderCanvasImage(
    width: _canvas,
    height: _canvas,
    draw: (final ui.Canvas canvas) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = color);
    },
  );
}

UserActionDrawing _imageAction(final ui.Image image, final Offset at) {
  return UserActionDrawing(
    action: ActionType.image,
    positions: <Offset>[at, Offset(at.dx + image.width, at.dy + image.height)],
    image: image,
  );
}

/// Renders [layer] exactly as the canvas composites it (group saveLayer +
/// renderLayer) and reads back straight RGBA bytes for comparison.
Future<Uint8List> _renderBytes(final LayerProvider layer) async {
  final ui.Image image = await layer.toImageForStorageAsync(_size);
  final Uint8List? pixels = await extractImagePixels(image, format: ui.ImageByteFormat.rawStraightRgba);
  image.dispose();
  expect(pixels, isNotNull);
  return pixels!;
}

int _alphaAt(final Uint8List rgba, final int x, final int y) =>
    rgba[((y * _canvas) + x) * AppMath.bytesPerPixel + AppMath.rgbChannelAlpha];

void main() {
  group('stroke-preview render equivalence', () {
    test('baseline + active action matches a full action-stack replay (additive)', () async {
      final ui.Image committed = await _solid(const Color(0xFFFF0000)); // red, full canvas
      final ui.Image activeImg = await _solid(const Color(0xFF0000FF)); // blue square

      // Reference: full replay of [committed image, active image], no baseline.
      final LayerProvider reference = _layer();
      reference.actionStack
        ..add(_imageAction(committed, Offset.zero))
        ..add(_imageAction(activeImg, const Offset(2, 2)));
      final Uint8List referenceBytes = await _renderBytes(reference);

      // Stroke path: commit the first action, freeze the baseline, then draw the
      // active action on top with isUserDrawing = true.
      final LayerProvider stroke = _layer();
      stroke.actionStack.add(_imageAction(committed, Offset.zero));
      stroke.beginStrokePreview();
      stroke.actionStack.add(_imageAction(activeImg, const Offset(2, 2)));
      stroke.isUserDrawing = true;
      final Uint8List strokeBytes = await _renderBytes(stroke);

      expect(strokeBytes, equals(referenceBytes));
    });

    test('active eraser clears into the frozen baseline exactly like a replay', () async {
      // Reference: red fill, then an eraser stroke across the middle — full replay.
      final LayerProvider reference = _layer();
      reference.actionStack
        ..add(_imageAction(await _solid(const Color(0xFFFF0000)), Offset.zero))
        ..add(
          UserActionDrawing(
            action: ActionType.eraser,
            positions: const <Offset>[Offset(0, 4), Offset(8, 4)],
            brush: MyBrush(color: AppColors.transparent, size: 4),
          ),
        );
      final Uint8List referenceBytes = await _renderBytes(reference);

      // Stroke path: red committed + baseline frozen, eraser applied as the
      // active action against the pre-rasterized baseline.
      final LayerProvider stroke = _layer();
      stroke.actionStack.add(_imageAction(await _solid(const Color(0xFFFF0000)), Offset.zero));
      stroke.beginStrokePreview();
      stroke.actionStack.add(
        UserActionDrawing(
          action: ActionType.eraser,
          positions: const <Offset>[Offset(0, 4), Offset(8, 4)],
          brush: MyBrush(color: AppColors.transparent, size: 4),
        ),
      );
      stroke.isUserDrawing = true;
      final Uint8List strokeBytes = await _renderBytes(stroke);

      // The erased middle band is transparent and the corners stay opaque in
      // both renders — the clear blend reaches the baseline content identically.
      expect(_alphaAt(strokeBytes, 4, 4), _alphaAt(referenceBytes, 4, 4));
      expect(_alphaAt(strokeBytes, 4, 4), lessThan(AppLimits.rgbChannelMax));
      expect(_alphaAt(strokeBytes, 0, 0), _alphaAt(referenceBytes, 0, 0));
      expect(_alphaAt(strokeBytes, 0, 0), AppLimits.rgbChannelMax);
    });
  });

  group('stroke-preview lifecycle', () {
    test('clearStrokePreview disposes the frozen baseline texture', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFFFF0000)), Offset.zero));
      layer.beginStrokePreview();
      layer.isUserDrawing = true;

      // Render once via the stroke path, then end the stroke.
      await _renderBytes(layer);
      layer.isUserDrawing = false;
      layer.clearStrokePreview();

      // A second clear is a safe no-op (baseline already released).
      layer.clearStrokePreview();
    });

    test('falls back to a full replay when no baseline was captured', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFF00FF00)), Offset.zero));
      // isUserDrawing without a baseline must still render the content.
      layer.isUserDrawing = true;
      final Uint8List bytes = await _renderBytes(layer);
      expect(_alphaAt(bytes, 4, 4), AppLimits.rgbChannelMax);
    });
  });
}
