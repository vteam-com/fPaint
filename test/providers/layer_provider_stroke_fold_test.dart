import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layer_provider.dart';

const int _canvasWidth = 64;
const int _canvasHeight = 48;
const Size _canvasSize = Size(64, 48);
const double _displayScale = 0.5;
const Rect _viewport = Rect.fromLTWH(0, 0, 64, 48);

/// Event-loop turns allowed for the async fold render to land.
const int _maxFoldWaitTurns = 50;

/// A pixel on the stroke's path, in canvas coordinates.
const Offset _strokeSample = Offset(32, 24);

/// Red channel byte of a fully red pixel.
const int _fullRed = 255;

/// Channel slack for the downscaled projection.
const int _channelTolerance = 8;

const Color _green = Color(0xFF00FF00);
const Color _red = Color(0xFFFF0000);

LayerProvider _layer({void Function() onThumbnailChanged = _noop}) =>
    LayerProvider(name: 'L', size: _canvasSize, onThumbnailChanged: onThumbnailChanged);

void _noop() {}

Future<UserActionDrawing> _greenFill() async {
  final ui.Image image = await renderCanvasImage(
    width: _canvasWidth,
    height: _canvasHeight,
    draw: (ui.Canvas canvas) => canvas.drawRect(_viewport, Paint()..color = _green),
  );
  return ImageAction(
    positions: <Offset>[Offset.zero, Offset(_canvasWidth.toDouble(), _canvasHeight.toDouble())],
    image: image,
  );
}

StrokeAction _redStroke() => StrokeAction(
  action: ActionType.pencil,
  positions: const <Offset>[Offset(0, 24), Offset(64, 24)],
  brush: MyBrush(color: _red, size: 8),
);

/// A layer with a built display cache, mid-way through a red stroke.
Future<LayerProvider> _layerWithStroke({void Function() onThumbnailChanged = _noop}) async {
  final LayerProvider layer = _layer(onThumbnailChanged: onThumbnailChanged);
  layer.actionStack.add(await _greenFill());
  await layer.buildDisplayCache(_displayScale);
  layer.isUserDrawing = true;
  layer.beginStrokePreview();
  layer.appendDrawingAction(_redStroke());
  layer.isUserDrawing = false;
  return layer;
}

/// Mirrors the canvas pen-up sequence: finish the preview, then the generic
/// post-gesture cache clear.
void _penUp(LayerProvider layer) {
  layer.finishStrokePreview();
  layer.clearCache();
}

Future<void> _waitForDisplayCache(LayerProvider layer) async {
  for (int i = 0; i < _maxFoldWaitTurns && !layer.hasDisplayCache; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Renders [layer] for display and returns how many rebuilds were requested
/// plus the red byte at [_strokeSample].
Future<({int rebuilds, int red})> _renderForDisplay(LayerProvider layer) async {
  int rebuilds = 0;
  final ui.Image out = await renderCanvasImage(
    width: _canvasWidth,
    height: _canvasHeight,
    draw: (ui.Canvas canvas) => layer.renderLayerForViewportDisplay(
      canvas,
      _displayScale,
      () => rebuilds++,
      viewportBounds: _viewport,
      viewport: ViewportTransform.identity(),
      visibleCanvasBounds: _viewport,
      filterQuality: FilterQuality.medium,
    ),
  );
  final ByteData? bytes = await out.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  out.dispose();
  final int offset = ((_strokeSample.dy.toInt() * _canvasWidth) + _strokeSample.dx.toInt()) * 4;
  return (rebuilds: rebuilds, red: bytes!.getUint8(offset));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LayerStrokeFold', () {
    test('a finished stroke is folded into the display cache instead of replaying history', () async {
      int thumbnailChanges = 0;
      final LayerProvider layer = await _layerWithStroke(onThumbnailChanged: () => thumbnailChanges++);

      _penUp(layer);

      // While the fold renders, the baseline + stroke stay on screen and no
      // full-history projection build is requested.
      final ({int rebuilds, int red}) during = await _renderForDisplay(layer);
      expect(during.rebuilds, 0);
      expect(during.red, closeTo(_fullRed, _channelTolerance));

      await _waitForDisplayCache(layer);
      expect(layer.hasDisplayCache, isTrue);
      expect(thumbnailChanges, greaterThan(0));

      final ({int rebuilds, int red}) after = await _renderForDisplay(layer);
      expect(after.rebuilds, 0);
      expect(after.red, closeTo(_fullRed, _channelTolerance));
    });

    test('an edit during the fold discards it and falls back to a rebuild', () async {
      final LayerProvider layer = await _layerWithStroke();

      _penUp(layer);
      layer.appendDrawingAction(_redStroke());
      await _waitForDisplayCache(layer);

      expect(layer.hasDisplayCache, isFalse);
      expect((await _renderForDisplay(layer)).rebuilds, 1);
    });

    test('a new stroke during the fold discards the old fold', () async {
      final LayerProvider layer = await _layerWithStroke();

      _penUp(layer);
      layer.isUserDrawing = true;
      layer.beginStrokePreview();
      await _waitForDisplayCache(layer);

      expect(layer.hasDisplayCache, isFalse);
      layer.clearStrokePreview();
    });

    test('without a display-res baseline the stroke preview is simply released', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(await _greenFill());
      layer.isUserDrawing = true;
      layer.beginStrokePreview();
      layer.appendDrawingAction(_redStroke());
      layer.isUserDrawing = false;

      _penUp(layer);
      await _waitForDisplayCache(layer);

      expect(layer.hasDisplayCache, isFalse);
      expect((await _renderForDisplay(layer)).rebuilds, 1);
    });

    test('a long pencil stroke folds mid-stroke and still matches a full replay', () async {
      final List<Offset> points = _zigZag(AppInteraction.strokePreviewFoldThreshold * 3);
      final MyBrush brush = MyBrush(color: _red, size: 3);

      final LayerProvider reference = _layer();
      reference.actionStack
        ..add(await _greenFill())
        ..add(StrokeAction(action: ActionType.pencil, positions: List<Offset>.of(points), brush: brush));
      final Uint8List referenceBytes = await _renderViewport(reference);

      final LayerProvider stroke = _layer();
      stroke.actionStack.add(await _greenFill());
      await stroke.buildDisplayCache(_nativeScale);
      stroke.isUserDrawing = true;
      stroke.beginStrokePreview();
      stroke.appendDrawingAction(
        StrokeAction(action: ActionType.pencil, positions: <Offset>[points.first], brush: brush),
      );
      for (int i = 1; i < points.length; i++) {
        stroke.lastActionAppendPosition(position: points[i]);
        await _renderViewport(stroke);
      }

      expect(await _renderViewport(stroke), equals(referenceBytes));

      // Proof the head was baked into the baseline rather than replayed: moving
      // an early point in place leaves the preview unchanged.
      _displaceEarlyPoint(stroke);
      expect(await _renderViewport(stroke), equals(referenceBytes));
      stroke.isUserDrawing = false;
      stroke.clearStrokePreview();
    });

    test('a translucent brush is never split mid-action', () async {
      final List<Offset> points = _zigZag(AppInteraction.strokePreviewFoldThreshold * 2);
      final LayerProvider stroke = _layer();
      stroke.actionStack.add(await _greenFill());
      await stroke.buildDisplayCache(_nativeScale);
      stroke.isUserDrawing = true;
      stroke.beginStrokePreview();
      stroke.appendDrawingAction(
        StrokeAction(
          action: ActionType.brush,
          positions: <Offset>[points.first],
          brush: MyBrush(color: _translucentRed, size: 3),
        ),
      );
      for (int i = 1; i < points.length; i++) {
        stroke.lastActionAppendPosition(position: points[i]);
        await _renderViewport(stroke);
      }

      // Nothing was baked, so moving an early point redraws the preview.
      final Uint8List before = await _renderViewport(stroke);
      _displaceEarlyPoint(stroke);
      expect(await _renderViewport(stroke), isNot(equals(before)));
      stroke.isUserDrawing = false;
      stroke.clearStrokePreview();
    });
  });
}

/// Display-cache scale equal to native resolution, so a folded baseline is
/// pixel-comparable with a full replay.
const double _nativeScale = 1.0;

const Color _translucentRed = Color(0x80FF0000);

/// A zig-zag polyline of [count] points across the canvas.
List<Offset> _zigZag(int count) => <Offset>[
  for (int i = 0; i < count; i++)
    Offset((i % _canvasWidth).toDouble(), (i.isEven ? _canvasHeight / 4 : _canvasHeight * 3 / 4)),
];

/// Index of the in-progress stroke point moved by [_displaceEarlyPoint].
const int _earlyPointIndex = 1;

/// Where [_displaceEarlyPoint] moves it: off the zig-zag's two rows.
const Offset _displacedPoint = Offset(2, 2);

/// Moves an early point of [layer]'s in-progress stroke in place, so only a
/// replay (not a baked baseline) would show the change.
void _displaceEarlyPoint(LayerProvider layer) {
  layer.actionStack.last.positions[_earlyPointIndex] = _displacedPoint;
}

/// Renders [layer] through the viewport path and returns its RGBA bytes.
Future<Uint8List> _renderViewport(LayerProvider layer) async {
  final ui.Image out = await renderCanvasImage(
    width: _canvasWidth,
    height: _canvasHeight,
    draw: (ui.Canvas canvas) => layer.renderLayerInViewport(
      canvas,
      viewportBounds: _viewport,
      viewport: ViewportTransform.identity(),
      visibleCanvasBounds: _viewport,
    ),
  );
  final ByteData? bytes = await out.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  out.dispose();
  return bytes!.buffer.asUint8List();
}
