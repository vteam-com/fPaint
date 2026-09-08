import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/providers/selection_effect_preview_state.dart';
import 'package:fpaint/providers/selection_effect_renderer.dart';
import 'package:material_ui/material_ui.dart';

/// Renders a solid [color] image of [width] x [height].
ui.Image _solidImage({
  int width = 40,
  int height = 40,
  Color color = const Color(0xFFFF0000),
}) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImageSync(width, height);
}

/// Reads the pixel at [x],[y] as an ARGB value.
Future<int> _pixelAt(ui.Image image, int x, int y) async {
  final ByteData? data = await image.toByteData();
  final int offset = (y * image.width + x) * 4;
  final int r = data!.getUint8(offset);
  final int g = data.getUint8(offset + 1);
  final int b = data.getUint8(offset + 2);
  final int a = data.getUint8(offset + 3);
  return (a << 24) | (r << 16) | (g << 8) | b;
}

void main() {
  const SelectionEffectRenderer renderer = SelectionEffectRenderer();

  group('SelectionEffectRenderer.maskToSelection', () {
    test('keeps pixels inside the selection and clears those outside', () async {
      final ui.Image source = _solidImage();
      addTearDown(source.dispose);

      // Selection covering only the left half of the image's bounds.
      final Path selectionPath = Path()..addRect(const Rect.fromLTWH(0, 0, 20, 40));
      final ui.Image masked = await renderer.maskToSelection(
        source,
        selectionPath: selectionPath,
        bounds: const Rect.fromLTWH(0, 0, 40, 40),
        pixelScale: AppEffects.defaultPixelScale,
      );
      addTearDown(masked.dispose);

      expect(await _pixelAt(masked, 5, 20), 0xFFFF0000);
      expect(await _pixelAt(masked, 35, 20), 0x00000000);
    });

    test('shifts the selection into image-local space using bounds', () async {
      final ui.Image source = _solidImage();
      addTearDown(source.dispose);

      // A selection positioned at (100, 100) in canvas space whose bounds match
      // must map to the image's own origin.
      final Path selectionPath = Path()..addRect(const Rect.fromLTWH(100, 100, 40, 40));
      final ui.Image masked = await renderer.maskToSelection(
        source,
        selectionPath: selectionPath,
        bounds: const Rect.fromLTWH(100, 100, 40, 40),
        pixelScale: AppEffects.defaultPixelScale,
      );
      addTearDown(masked.dispose);

      expect(await _pixelAt(masked, 20, 20), 0xFFFF0000);
    });

    test('scales the selection path by the pixel scale', () async {
      final ui.Image source = _solidImage(width: 20, height: 20);
      addTearDown(source.dispose);

      // The proxy is half size, so a full-res 40-wide selection covers it all.
      final Path selectionPath = Path()..addRect(const Rect.fromLTWH(0, 0, 40, 40));
      final ui.Image masked = await renderer.maskToSelection(
        source,
        selectionPath: selectionPath,
        bounds: const Rect.fromLTWH(0, 0, 40, 40),
        pixelScale: 0.5,
      );
      addTearDown(masked.dispose);

      expect(await _pixelAt(masked, 18, 18), 0xFFFF0000);
    });
  });

  group('SelectionEffectRenderer.buildPreviewProxy', () {
    test('returns the source unchanged when it fits the preview budget', () async {
      final ui.Image source = _solidImage(width: 32, height: 32);
      addTearDown(source.dispose);

      final ({ui.Image image, double scale}) proxy = await renderer.buildPreviewProxy(source);

      expect(identical(proxy.image, source), isTrue);
      expect(proxy.scale, AppEffects.defaultPixelScale);
    });

    test('downscales an oversized source and reports the scale', () async {
      const int oversized = AppLimits.effectPreviewMaxDimension * 2;
      final ui.Image source = _solidImage(width: oversized, height: oversized ~/ 2);
      addTearDown(source.dispose);

      final ({ui.Image image, double scale}) proxy = await renderer.buildPreviewProxy(source);
      addTearDown(proxy.image.dispose);

      expect(identical(proxy.image, source), isFalse);
      expect(proxy.scale, closeTo(0.5, 0.001));
      expect(proxy.image.width, AppLimits.effectPreviewMaxDimension);
      expect(proxy.image.height, oversized ~/ 4);
    });
  });

  group('SelectionEffectRenderer.buildMaskedImage', () {
    /// Builds preview state over the whole of [image].
    SelectionEffectPreviewState stateFor(
      ui.Image image, {
      required bool coversEntireLayer,
      double strength = 0.0,
      SelectionEffect effect = SelectionEffect.blur,
    }) {
      final Rect bounds = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      return SelectionEffectPreviewState(
        effect: effect,
        sourceImage: image,
        pixelScale: AppEffects.defaultPixelScale,
        selectionPath: Path()..addRect(bounds),
        bounds: bounds,
        strength: strength,
        size: AppEffects.minSize,
        coversEntireLayer: coversEntireLayer,
      );
    }

    test('returns a copy, not the source, for a whole-layer no-op', () async {
      final ui.Image source = _solidImage();
      addTearDown(source.dispose);

      final ui.Image result = await renderer.buildMaskedImage(
        stateFor(source, coversEntireLayer: true),
      );
      addTearDown(result.dispose);

      // A copy means the caller can dispose the result without freeing the
      // preview's retained source image.
      expect(identical(result, source), isFalse);
      expect(await _pixelAt(result, 20, 20), 0xFFFF0000);
    });

    test('masks the result to the selection when it does not cover the layer', () async {
      final ui.Image source = _solidImage();
      addTearDown(source.dispose);

      final SelectionEffectPreviewState state = SelectionEffectPreviewState(
        effect: SelectionEffect.blur,
        sourceImage: source,
        pixelScale: AppEffects.defaultPixelScale,
        selectionPath: Path()..addRect(const Rect.fromLTWH(0, 0, 20, 40)),
        bounds: const Rect.fromLTWH(0, 0, 40, 40),
        strength: 0.0,
        size: AppEffects.minSize,
        coversEntireLayer: false,
      );

      final ui.Image result = await renderer.buildMaskedImage(state);
      addTearDown(result.dispose);

      expect(identical(result, source), isFalse);
      expect(await _pixelAt(result, 35, 20), 0x00000000);
    });

    test('leaves the source image usable after building', () async {
      final ui.Image source = _solidImage();
      addTearDown(source.dispose);

      final ui.Image result = await renderer.buildMaskedImage(
        stateFor(source, coversEntireLayer: false),
      );
      result.dispose();

      // The retained source must survive the render + dispose cycle.
      expect(await _pixelAt(source, 20, 20), 0xFFFF0000);
    });
  });
}
