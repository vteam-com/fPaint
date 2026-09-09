import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/layers_provider_test_helper.dart';

const Color _red = Color(0xFFFF0000);

Future<ui.Image> _solidImage(int width, int height, Color color) {
  return renderCanvasImage(
    width: width,
    height: height,
    draw: (ui.Canvas canvas) => canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = color,
    ),
  );
}

Future<Color> _readPixel(ui.Image image, int x, int y) async {
  final Uint8List? pixels = await extractImagePixels(
    image,
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  expect(pixels, isNotNull);
  final int index = ((y * image.width) + x) * AppMath.bytesPerPixel;
  return Color.fromARGB(
    pixels![index + AppMath.rgbChannelAlpha],
    pixels[index + AppMath.rgbChannelRed],
    pixels[index + AppMath.rgbChannelGreen],
    pixels[index + AppMath.rgbChannelBlue],
  );
}

void main() {
  late UndoProvider undoProvider;
  late LayersProvider layers;
  late LayerProvider background;
  late LayerProvider paint;

  setUp(() async {
    undoProvider = UndoProvider();
    layers = createInitializedLayersProvider(size: const Size(100, 100), undoProvider: undoProvider);
    background = layers.get(0);
    paint = layers.insertAt(0, 'Paint');
    // A 40×40 red square in the top-left corner of a 100×100 canvas.
    paint.addImage(imageToAdd: await _solidImage(40, 40, _red));
    layers.clearHasChanged();
  });

  group('LayersProvider.resizeImage', () {
    test('ignores non-positive and unchanged sizes', () async {
      await layers.resizeImage(0, 50);
      await layers.resizeImage(50, -1);
      await layers.resizeImage(100, 100);

      expect(layers.size, const Size(100, 100));
      expect(undoProvider.canUndo, isFalse);
      expect(paint.actionStack.single.image!.width, 40);
    });

    test('enlarging scales the content and flattens the layer to one image', () async {
      await layers.resizeImage(200, 200);

      expect(layers.size, const Size(200, 200));
      expect(paint.size, const Size(200, 200));
      expect(paint.actionStack, hasLength(1));
      final UserActionDrawing action = paint.actionStack.single;
      expect(action, isA<ImageAction>());
      expect(action.image!.width, 200);
      expect(action.image!.height, 200);
      expect(action.positions.first, Offset.zero);
      expect(paint.hasChanged, isTrue);

      // The 40×40 square now covers 80×80.
      expect(await _readPixel(action.image!, 60, 60), _red);
      expect((await _readPixel(action.image!, 120, 120)).a, 0);
    });

    test('shrinking scales the content down', () async {
      await layers.resizeImage(50, 50);

      final ui.Image scaled = paint.actionStack.single.image!;
      expect(scaled.width, 50);
      expect(await _readPixel(scaled, 10, 10), _red);
      expect((await _readPixel(scaled, 40, 40)).a, 0);
    });

    test('supports independent horizontal and vertical factors', () async {
      await layers.resizeImage(200, 50);

      final ui.Image scaled = paint.actionStack.single.image!;
      expect(scaled.width, 200);
      expect(scaled.height, 50);
      // 40×40 → 80×20.
      expect(await _readPixel(scaled, 70, 10), _red);
      expect((await _readPixel(scaled, 90, 10)).a, 0);
      expect((await _readPixel(scaled, 70, 30)).a, 0);
    });

    test('keeps a background-only layer as a fill instead of rasterizing it', () async {
      await layers.resizeImage(200, 200);

      expect(background.backgroundColor, AppColors.white);
      expect(background.actionStack, isEmpty);
      expect(background.size, const Size(200, 200));
    });

    test('leaves an empty layer without a texture', () async {
      final LayerProvider empty = layers.insertAt(0, 'Empty');
      expect(empty.backgroundColor, isNull);

      await layers.resizeImage(200, 200);

      expect(empty.actionStack, isEmpty);
      expect(empty.size, const Size(200, 200));
    });

    test('bakes a painted layer\'s fill into the resampled raster', () async {
      paint.backgroundColor = const Color(0xFF0000FF);

      await layers.resizeImage(200, 200);

      expect(paint.backgroundColor, isNull);
      final ui.Image scaled = paint.actionStack.single.image!;
      expect(await _readPixel(scaled, 60, 60), _red);
      expect(await _readPixel(scaled, 150, 150), const Color(0xFF0000FF));
    });

    test('undo restores the original stacks and size, redo re-applies', () async {
      final ui.Image original = paint.actionStack.single.image!;
      await layers.resizeImage(200, 200);
      final ui.Image scaled = paint.actionStack.single.image!;
      expect(undoProvider.canUndo, isTrue);

      await undoProvider.undo();
      expect(layers.size, const Size(100, 100));
      expect(paint.size, const Size(100, 100));
      expect(identical(paint.actionStack.single.image, original), isTrue);
      expect(paint.hasChanged, isFalse);
      // The original texture must still be usable after undo.
      expect(await _readPixel(original, 10, 10), _red);

      await undoProvider.redo();
      expect(layers.size, const Size(200, 200));
      expect(identical(paint.actionStack.single.image, scaled), isTrue);
      expect(await _readPixel(scaled, 60, 60), _red);
    });

    test('records exactly one undo step for the whole stack', () async {
      await layers.resizeImage(200, 200);
      expect(undoProvider.canUndo, isTrue);
      await undoProvider.undo();
      expect(undoProvider.canUndo, isFalse);
    });
  });
}
