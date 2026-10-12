import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layer_provider.dart';
import 'package:fpaint/providers/stroke_composite_controller.dart';
import 'package:fpaint/providers/stroke_layer_composite.dart';
import 'package:fpaint/widgets/canvas_panel_painter.dart';

const int _side = 32;
const Size _canvasSize = Size(32, 32);
const Rect _canvasRect = Rect.fromLTWH(0, 0, 32, 32);
const double _fullScale = 1.0;
const double _halfOpacity = 0.5;

/// Per-channel slack between the flattened and per-layer composites.
const int _channelTolerance = 2;

void _noop() {}

/// A layer filled over [rect] with [color], with a display cache built.
Future<LayerProvider> _layer(Color color, {Rect rect = _canvasRect, double opacity = 1.0}) async {
  final LayerProvider layer = LayerProvider(name: 'L', size: _canvasSize, onThumbnailChanged: _noop);
  final ui.Image image = await renderCanvasImage(
    width: _side,
    height: _side,
    draw: (ui.Canvas canvas) => canvas.drawRect(rect, Paint()..color = color),
  );
  layer.actionStack.add(
    ImageAction(positions: const <Offset>[Offset.zero, Offset(32, 32)], image: image),
  );
  layer.opacity = opacity;
  await layer.buildDisplayCache(_fullScale);
  return layer;
}

/// Resolves until the controller's build lands and returns the composite.
Future<StrokeLayerComposite?> _resolveBuilt(List<LayerProvider> layers) async {
  final Completer<void> ready = Completer<void>();
  final StrokeCompositeController controller = StrokeCompositeController(onReady: ready.complete);
  expect(controller.resolve(layers), isNull);
  await ready.future;
  return controller.resolve(layers);
}

/// Paints [layers] through [CanvasPanelPainter] and returns the RGBA bytes.
Future<Uint8List> _paint(
  List<LayerProvider> layers, {
  StrokeLayerComposite? Function(List<LayerProvider>)? resolve,
}) async {
  final CanvasPanelPainter painter = CanvasPanelPainter(
    layers,
    viewport: ViewportTransform.identity(),
    visibleCanvasBounds: _canvasRect,
    onNeedsDisplayCache: (LayerProvider _, double _) {},
    resolveStrokeComposite: resolve,
  );
  final ui.Image out = await renderCanvasImage(
    width: _side,
    height: _side,
    draw: (ui.Canvas canvas) => painter.paint(canvas, _canvasSize),
  );
  final ByteData? bytes = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  out.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StrokeCompositeController', () {
    test('returns nothing and builds nothing when no layer is drawing', () async {
      bool built = false;
      final StrokeCompositeController controller = StrokeCompositeController(onReady: () => built = true);
      final List<LayerProvider> layers = <LayerProvider>[
        await _layer(const Color(0xFF0000FF)),
        await _layer(const Color(0xFF00FF00)),
      ];

      expect(controller.resolve(layers), isNull);
      await pumpEventQueue();
      expect(built, isFalse);
    });

    test('flattens the layers below the active one into a single image', () async {
      final LayerProvider active = await _layer(const Color(0xFFFF0000), rect: const Rect.fromLTWH(8, 8, 8, 8));
      final LayerProvider middle = await _layer(const Color(0xFF00FF00), opacity: _halfOpacity);
      final LayerProvider bottom = await _layer(const Color(0xFF0000FF));
      final List<LayerProvider> layers = <LayerProvider>[active, middle, bottom];
      active.isUserDrawing = true;

      final StrokeLayerComposite? composite = await _resolveBuilt(layers);

      expect(composite, isNotNull);
      expect(composite!.groupImageFor(active), isNull);
      expect(composite.groupImageFor(middle), isNotNull);
      expect(identical(composite.groupImageFor(middle), composite.groupImageFor(bottom)), isTrue);
    });

    test('painting with the composite matches painting every layer', () async {
      final LayerProvider top = await _layer(const Color(0x80FFFF00), rect: const Rect.fromLTWH(0, 0, 16, 32));
      final LayerProvider upper = await _layer(const Color(0xFF00FFFF), rect: const Rect.fromLTWH(20, 0, 12, 12));
      final LayerProvider active = await _layer(const Color(0xFFFF0000), rect: const Rect.fromLTWH(8, 8, 16, 16));
      final LayerProvider middle = await _layer(const Color(0xFF00FF00), opacity: _halfOpacity);
      final LayerProvider bottom = await _layer(const Color(0xFF0000FF), rect: const Rect.fromLTWH(0, 16, 32, 16));
      final List<LayerProvider> layers = <LayerProvider>[top, upper, active, middle, bottom];
      active.isUserDrawing = true;

      final StrokeLayerComposite? composite = await _resolveBuilt(layers);
      expect(composite!.groupImageFor(top), isNotNull);
      expect(composite.groupImageFor(bottom), isNotNull);

      final Uint8List perLayer = await _paint(layers);
      final Uint8List flattened = await _paint(layers, resolve: (List<LayerProvider> _) => composite);
      for (int i = 0; i < perLayer.length; i++) {
        expect((perLayer[i] - flattened[i]).abs(), lessThanOrEqualTo(_channelTolerance), reason: 'byte $i');
      }
    });

    test('leaves a side with a non-srcOver layer unflattened', () async {
      final LayerProvider active = await _layer(const Color(0xFFFF0000));
      final LayerProvider multiply = await _layer(const Color(0xFF00FF00));
      multiply.blendMode = ui.BlendMode.multiply;
      final LayerProvider bottom = await _layer(const Color(0xFF0000FF));
      final List<LayerProvider> layers = <LayerProvider>[active, multiply, bottom];
      active.isUserDrawing = true;

      final StrokeLayerComposite? composite = await _resolveBuilt(layers);

      expect(composite!.groupImageFor(multiply), isNull);
      expect(composite.groupImageFor(bottom), isNull);
    });

    test('drops the composite when the stroke ends or the stack changes', () async {
      final LayerProvider active = await _layer(const Color(0xFFFF0000));
      final LayerProvider middle = await _layer(const Color(0xFF00FF00));
      final LayerProvider bottom = await _layer(const Color(0xFF0000FF));
      final List<LayerProvider> layers = <LayerProvider>[active, middle, bottom];
      active.isUserDrawing = true;
      final Completer<void> ready = Completer<void>();
      final StrokeCompositeController controller = StrokeCompositeController(onReady: ready.complete);
      controller.resolve(layers);
      await ready.future;
      expect(controller.resolve(layers), isNotNull);

      middle.opacity = _halfOpacity;
      expect(controller.resolve(layers), isNull, reason: 'stale after a compositing change');

      active.isUserDrawing = false;
      expect(controller.resolve(layers), isNull);
      controller.release();
    });

    test('ignores multi-layer strokes', () async {
      final LayerProvider first = await _layer(const Color(0xFFFF0000));
      final LayerProvider second = await _layer(const Color(0xFF00FF00));
      final LayerProvider third = await _layer(const Color(0xFF0000FF));
      first.isUserDrawing = true;
      second.isUserDrawing = true;
      bool built = false;
      final StrokeCompositeController controller = StrokeCompositeController(onReady: () => built = true);

      expect(controller.resolve(<LayerProvider>[first, second, third]), isNull);
      await pumpEventQueue();
      expect(built, isFalse);
    });
  });
}
