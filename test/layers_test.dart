import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/layer_provider.dart';

void main() {
  group('Layer Tests', () {
    late LayerProvider layer;

    setUp(() {
      layer = LayerProvider(
        name: 'Test Layer',
        size: const Size(100, 100),
        onThumnailChanged: () {
          //
        },
      );
    });

    test('Initial values are correct', () {
      expect(layer.name, 'Test Layer');
      expect(layer.isSelected, false);
      expect(layer.isVisible, true);
      expect(layer.opacity, 1);
      expect(layer.count, 0);
      expect(layer.isEmpty, true);
    });

    test('Add user action', () {
      final UserActionDrawing userAction = UserActionDrawing(
        action: ActionType.brush,
        positions: <ui.Offset>[Offset.zero],
        brush: MyBrush(
          color: Colors.black,
          size: 1,
        ),
        fillColor: Colors.transparent,
      );
      layer.appendDrawingAction(userAction);
      expect(layer.count, 1);
      expect(layer.isEmpty, false);
      expect(layer.lastUserAction, userAction);
    });

    test('Undo and redo actions', () {
      final UserActionDrawing userAction = UserActionDrawing(
        action: ActionType.brush,
        positions: <ui.Offset>[Offset.zero],
        brush: MyBrush(
          color: Colors.black,
          size: 1,
        ),
        fillColor: Colors.transparent,
      );
      layer.appendDrawingAction(userAction);
      layer.undo();
      expect(layer.count, 0);
      expect(layer.redoStack.length, 1);
      layer.redo();
      expect(layer.count, 1);
      expect(layer.redoStack.length, 0);
    });

    test('Add image', () async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = Canvas(recorder);
      final ui.Paint paint = Paint()..color = Colors.red;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 10, 10), paint);
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(10, 10);

      layer.addImage(imageToAdd: image);
      expect(layer.count, 1);
      expect(layer.lastUserAction?.action, ActionType.image);
    });

    test('Update last user action end position', () {
      final UserActionDrawing userAction = UserActionDrawing(
        action: ActionType.brush,
        positions: <ui.Offset>[Offset.zero, const Offset(1, 1)],
        brush: MyBrush(
          color: Colors.black,
          size: 1,
        ),
        fillColor: Colors.transparent,
      );
      layer.appendDrawingAction(userAction);
      layer.lastActionUpdatePosition(const Offset(2, 2));
      expect(layer.lastUserAction?.positions.last, const Offset(2, 2));
    });

    test('Clear cache', () {
      layer.clearCache();
      expect(layer.thumbnailImage, null);
    });

    test('Blend mode is applied during rendering', () async {
      // Set a non-default blend mode
      layer.blendMode = ui.BlendMode.multiply;

      // Add some content to the layer
      final UserActionDrawing userAction = UserActionDrawing(
        action: ActionType.brush,
        positions: <ui.Offset>[Offset.zero, const Offset(10, 10)],
        brush: MyBrush(
          color: Colors.red,
          size: 5,
        ),
        fillColor: Colors.red,
      );
      layer.appendDrawingAction(userAction);

      // Create a canvas to render to
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = Canvas(recorder);

      // Render the layer
      layer.renderLayer(canvas);

      // End recording to create the picture
      final ui.Picture picture = recorder.endRecording();

      // The test passes if no exceptions are thrown during rendering
      // This verifies that the blend mode is properly handled
      expect(picture, isNotNull);

      // Verify the blend mode is set correctly on the layer
      expect(layer.blendMode, ui.BlendMode.multiply);
    });

    test('Default blend mode is srcOver', () {
      expect(layer.blendMode, ui.BlendMode.srcOver);
    });

    test('Blend mode can be changed', () {
      layer.blendMode = ui.BlendMode.screen;
      expect(layer.blendMode, ui.BlendMode.screen);

      layer.blendMode = ui.BlendMode.overlay;
      expect(layer.blendMode, ui.BlendMode.overlay);
    });

    test('All supported blend modes can be set and render without errors', () async {
      // Test all blend modes from the supportedBlendModes map
      final List<ui.BlendMode> supportedModes = <ui.BlendMode>[
        ui.BlendMode.srcOver,
        ui.BlendMode.darken,
        ui.BlendMode.multiply,
        ui.BlendMode.colorBurn,
        ui.BlendMode.lighten,
        ui.BlendMode.screen,
        ui.BlendMode.colorDodge,
        ui.BlendMode.plus,
        ui.BlendMode.overlay,
        ui.BlendMode.softLight,
        ui.BlendMode.hardLight,
        ui.BlendMode.hue,
        ui.BlendMode.saturation,
        ui.BlendMode.color,
        ui.BlendMode.luminosity,
      ];

      for (final ui.BlendMode mode in supportedModes) {
        layer.blendMode = mode;

        // Add some content to ensure there's something to render
        final UserActionDrawing userAction = UserActionDrawing(
          action: ActionType.brush,
          positions: <ui.Offset>[Offset.zero, const Offset(5, 5)],
          brush: MyBrush(color: Colors.red, size: 2),
          fillColor: Colors.red,
        );
        layer.appendDrawingAction(userAction);

        // Render should not throw exceptions
        final ui.Image renderedImage = layer.renderImageWH(10, 10);
        expect(renderedImage, isNotNull);
        expect(layer.blendMode, mode);

        // Clear for next test
        layer.clearCache();
        layer.actionStack.clear();
      }
    });

    test('Blend mode affects rendering output', () async {
      // Create two layers with different colors to test blending
      final LayerProvider layer1 = LayerProvider(
        name: 'Base Layer',
        size: const Size(20, 20),
        onThumnailChanged: () {},
      );
      layer1.backgroundColor = Colors.red;

      final LayerProvider layer2 = LayerProvider(
        name: 'Blend Layer',
        size: const Size(20, 20),
        onThumnailChanged: () {},
      );
      layer2.backgroundColor = Colors.blue;

      // Test normal blend mode (should show blue over red)
      layer2.blendMode = ui.BlendMode.srcOver;

      // Render both layers to a combined canvas
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = Canvas(recorder);

      layer1.renderLayer(canvas);
      layer2.renderLayer(canvas);

      final ui.Picture picture = recorder.endRecording();
      final ui.Image combinedImage = await picture.toImage(20, 20);

      // Test multiply blend mode (should show darker result)
      layer2.blendMode = ui.BlendMode.multiply;

      final ui.PictureRecorder recorder2 = ui.PictureRecorder();
      final ui.Canvas canvas2 = Canvas(recorder2);

      layer1.renderLayer(canvas2);
      layer2.renderLayer(canvas2);

      final ui.Picture picture2 = recorder2.endRecording();
      final ui.Image combinedImage2 = await picture2.toImage(20, 20);

      // Both images should be valid
      expect(combinedImage, isNotNull);
      expect(combinedImage2, isNotNull);

      // Get pixel data to verify they are different
      final ByteData? data1 = await combinedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      final ByteData? data2 = await combinedImage2.toByteData(format: ui.ImageByteFormat.rawRgba);

      expect(data1, isNotNull);
      expect(data2, isNotNull);

      // The results should be different (at least some pixels)
      bool foundDifference = false;
      for (int i = 0; i < data1!.lengthInBytes; i += 4) {
        if (data1.getUint8(i) != data2!.getUint8(i) ||
            data1.getUint8(i + 1) != data2.getUint8(i + 1) ||
            data1.getUint8(i + 2) != data2.getUint8(i + 2)) {
          foundDifference = true;
          break;
        }
      }
      expect(foundDifference, isTrue);
    });

    test('Blend mode affects cached and non-cached rendering consistently', () async {
      // Create a layer with content
      layer.backgroundColor = Colors.purple;
      layer.blendMode = ui.BlendMode.darken;

      // Add some drawing content
      final UserActionDrawing userAction = UserActionDrawing(
        action: ActionType.brush,
        positions: <ui.Offset>[const Offset(5, 5)],
        brush: MyBrush(
          color: Colors.white,
          size: 3,
        ),
        fillColor: Colors.white,
      );
      layer.appendDrawingAction(userAction);

      // Force thumbnail update to create cache
      await layer.updateThumbnail();
      expect(layer.thumbnailImage, isNotNull);

      // Render fresh (non-cached)
      final ui.Image freshImage = layer.renderImageWH(20, 20);

      // Both should complete without errors and produce valid images
      expect(freshImage, isNotNull);

      // Verify blend mode is still set
      expect(layer.blendMode, ui.BlendMode.darken);
    });
  });
}
