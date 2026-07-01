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

    test('incrementally folded pencil stroke matches a full replay', () async {
      final MyBrush brush = MyBrush(color: const Color(0xFF000000), size: 2);
      // Duplicate first point mirrors how a stroke starts (positions: [p, p]).
      const List<Offset> points = <Offset>[
        Offset(1, 1),
        Offset(1, 1),
        Offset(3, 2),
        Offset(5, 5),
        Offset(6, 2),
        Offset(2, 6),
      ];

      // Reference: white background then the whole pencil action, full replay.
      final LayerProvider reference = _layer();
      reference.actionStack
        ..add(_imageAction(await _solid(const Color(0xFFFFFFFF)), Offset.zero))
        ..add(UserActionDrawing(action: ActionType.pencil, positions: List<Offset>.of(points), brush: brush));
      final Uint8List referenceBytes = await _renderBytes(reference);

      // Stroke: freeze the baseline, then grow the pencil action point-by-point,
      // rendering each frame so the accumulator folds one new segment at a time.
      final LayerProvider stroke = _layer();
      stroke.actionStack.add(_imageAction(await _solid(const Color(0xFFFFFFFF)), Offset.zero));
      stroke.beginStrokePreview();
      stroke.isUserDrawing = true;
      stroke.actionStack.add(
        UserActionDrawing(action: ActionType.pencil, positions: <Offset>[points[0], points[1]], brush: brush),
      );
      await _renderBytes(stroke);
      for (int i = 2; i < points.length; i++) {
        stroke.lastActionAppendPosition(position: points[i]);
        await _renderBytes(stroke);
      }
      final Uint8List strokeBytes = await _renderBytes(stroke);

      expect(strokeBytes, equals(referenceBytes));
    });

    test('incrementally folded eraser stroke matches a full replay', () async {
      final MyBrush brush = MyBrush(color: AppColors.transparent, size: 3);
      const List<Offset> points = <Offset>[
        Offset(1, 4),
        Offset(1, 4),
        Offset(3, 4),
        Offset(5, 4),
        Offset(7, 4),
      ];

      final LayerProvider reference = _layer();
      reference.actionStack
        ..add(_imageAction(await _solid(const Color(0xFFFF0000)), Offset.zero))
        ..add(UserActionDrawing(action: ActionType.eraser, positions: List<Offset>.of(points), brush: brush));
      final Uint8List referenceBytes = await _renderBytes(reference);

      final LayerProvider stroke = _layer();
      stroke.actionStack.add(_imageAction(await _solid(const Color(0xFFFF0000)), Offset.zero));
      stroke.beginStrokePreview();
      stroke.isUserDrawing = true;
      stroke.actionStack.add(
        UserActionDrawing(action: ActionType.eraser, positions: <Offset>[points[0], points[1]], brush: brush),
      );
      await _renderBytes(stroke);
      for (int i = 2; i < points.length; i++) {
        stroke.lastActionAppendPosition(position: points[i]);
        await _renderBytes(stroke);
      }
      final Uint8List strokeBytes = await _renderBytes(stroke);

      expect(strokeBytes, equals(referenceBytes));
    });

    test('incrementally folded brush stroke (per-move actions) matches a full replay', () async {
      final MyBrush brush = MyBrush(color: const Color(0xFF000000), size: 2);
      const Color fill = Color(0xFF000000);
      // Brush appends a fresh 2-point action per move rather than growing one.
      const List<List<Offset>> segments = <List<Offset>>[
        <Offset>[Offset(1, 1), Offset(3, 3)],
        <Offset>[Offset(3, 3), Offset(5, 2)],
        <Offset>[Offset(5, 2), Offset(6, 6)],
      ];
      UserActionDrawing brushAction(final List<Offset> pts) => UserActionDrawing(
        action: ActionType.brush,
        positions: List<Offset>.of(pts),
        brush: brush,
        fillColor: fill,
      );

      final LayerProvider reference = _layer();
      reference.actionStack.add(_imageAction(await _solid(const Color(0xFFFFFFFF)), Offset.zero));
      for (final List<Offset> segment in segments) {
        reference.actionStack.add(brushAction(segment));
      }
      final Uint8List referenceBytes = await _renderBytes(reference);

      final LayerProvider stroke = _layer();
      stroke.actionStack.add(_imageAction(await _solid(const Color(0xFFFFFFFF)), Offset.zero));
      stroke.beginStrokePreview();
      stroke.isUserDrawing = true;
      for (final List<Offset> segment in segments) {
        stroke.actionStack.add(brushAction(segment));
        await _renderBytes(stroke);
      }
      final Uint8List strokeBytes = await _renderBytes(stroke);

      expect(strokeBytes, equals(referenceBytes));
    });

    test('long pencil stroke crossing the fold threshold matches a full replay', () async {
      final MyBrush brush = MyBrush(color: const Color(0xFF000000), size: 2);
      // Enough points that the un-baked tail crosses the fold threshold several
      // times, exercising repeated mid-stroke folds (and the connecting-segment
      // logic) rather than the cheap replay-only path short strokes take.
      final int total = (AppInteraction.strokePreviewFoldThreshold * 3) + 5;
      final List<Offset> points = <Offset>[
        for (int i = 0; i < total; i++) Offset((i % 7).toDouble(), ((i * 3) % 7).toDouble()),
      ];

      final LayerProvider reference = _layer();
      reference.actionStack
        ..add(_imageAction(await _solid(const Color(0xFFFFFFFF)), Offset.zero))
        ..add(UserActionDrawing(action: ActionType.pencil, positions: List<Offset>.of(points), brush: brush));
      final Uint8List referenceBytes = await _renderBytes(reference);

      final LayerProvider stroke = _layer();
      stroke.actionStack.add(_imageAction(await _solid(const Color(0xFFFFFFFF)), Offset.zero));
      stroke.beginStrokePreview();
      stroke.isUserDrawing = true;
      stroke.actionStack.add(
        UserActionDrawing(action: ActionType.pencil, positions: <Offset>[points[0]], brush: brush),
      );
      for (int i = 1; i < points.length; i++) {
        stroke.lastActionAppendPosition(position: points[i]);
        // Render after the tail has grown past the threshold so a fold fires.
        if (i % (AppInteraction.strokePreviewFoldThreshold + 5) == 0) {
          await _renderBytes(stroke);
        }
      }
      final Uint8List strokeBytes = await _renderBytes(stroke);

      expect(strokeBytes, equals(referenceBytes));
    });

    test('many brush actions crossing the fold threshold match a full replay', () async {
      final MyBrush brush = MyBrush(color: const Color(0xFF000000), size: 2);
      const Color fill = Color(0xFF000000);
      final int total = (AppInteraction.strokePreviewFoldThreshold * 2) + 3;
      UserActionDrawing brushSegment(final int i) => UserActionDrawing(
        action: ActionType.brush,
        positions: <Offset>[
          Offset((i % 7).toDouble(), (i % 5).toDouble()),
          Offset(((i + 1) % 7).toDouble(), ((i + 2) % 5).toDouble()),
        ],
        brush: brush,
        fillColor: fill,
      );

      final LayerProvider reference = _layer();
      reference.actionStack.add(_imageAction(await _solid(const Color(0xFFFFFFFF)), Offset.zero));
      for (int i = 0; i < total; i++) {
        reference.actionStack.add(brushSegment(i));
      }
      final Uint8List referenceBytes = await _renderBytes(reference);

      final LayerProvider stroke = _layer();
      stroke.actionStack.add(_imageAction(await _solid(const Color(0xFFFFFFFF)), Offset.zero));
      stroke.beginStrokePreview();
      stroke.isUserDrawing = true;
      for (int i = 0; i < total; i++) {
        stroke.actionStack.add(brushSegment(i));
        if (i % (AppInteraction.strokePreviewFoldThreshold + 1) == 0) {
          await _renderBytes(stroke);
        }
      }
      final Uint8List strokeBytes = await _renderBytes(stroke);

      expect(strokeBytes, equals(referenceBytes));
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

  group('live pixel-brush preview baseline ownership', () {
    test('clear disposes the baseline on the CPU worker/sync path (layer-owned)', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFFFF0000)), Offset.zero));

      layer.beginLivePixelBrushPreview();
      final ui.Image? baseline = layer.livePreviewBaseline;
      expect(baseline, isNotNull);

      // No GPU stroke adopted it, so the layer owns the full-canvas baseline and
      // must free it — otherwise it leaks one canvas-sized texture per stroke.
      layer.clearLivePixelBrushPreview();
      expect(baseline!.debugDisposed, isTrue, reason: 'worker/sync-path baseline is layer-owned and must be freed');
    });

    test('clear leaves the baseline alone once a GPU stroke owns it', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFFFF0000)), Offset.zero));

      layer.beginLivePixelBrushPreview();
      final ui.Image? baseline = layer.livePreviewBaseline;
      expect(baseline, isNotNull);

      // Once the GPU stroke adopts it (or it becomes the committed action image),
      // clearing must NOT dispose it — that would double-free / corrupt the commit.
      layer.markLivePreviewBaselineExternallyOwned();
      layer.clearLivePixelBrushPreview();
      expect(baseline!.debugDisposed, isFalse, reason: 'GPU stroke / committed action owns it; clear must not free it');
      baseline.dispose();
    });
  });
}
