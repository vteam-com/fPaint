import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/constants/constants.dart';

/// Lazily-generated, cached noise tile that gives the grain ("pencil") brush
/// style its paper texture.
///
/// Generated once — a small square tile from a fixed seed, so it is fully
/// deterministic — and reused for the app lifetime. The stroke renderer samples
/// it as a repeating [ui.ImageShader] in canvas space, so the grain reads as a
/// stationary paper texture that the stroke reveals. Generation is async
/// ([decodeImageFromPixels]); until [prewarm] completes, the grain style falls
/// back to a solid stroke.
class BrushGrain {
  BrushGrain._();

  /// The shared instance.
  static final BrushGrain instance = BrushGrain._();

  ui.Image? _tile;
  Future<void>? _pending;

  /// The cached noise tile, or null until [prewarm] has completed.
  ui.Image? get tile => _tile;

  /// Generates the noise tile once. Idempotent and safe to call repeatedly.
  Future<void> prewarm() {
    if (_tile != null) {
      return Future<void>.value();
    }
    return _pending ??= _generate();
  }

  /// Builds the tile: white RGBA texels whose alpha varies in [minAlpha, 255]
  /// (the speckle), decoded to a [ui.Image] and cached in [_tile].
  Future<void> _generate() async {
    const int size = AppBrushGrain.tileSize;
    const int channelMax = AppLimits.rgbChannelMax;
    final int alphaRange = channelMax + AppMath.one - AppBrushGrain.minAlpha;
    final int texelCount = size * size;
    final Uint8List pixels = Uint8List(texelCount * AppMath.bytesPerPixel);
    final Random random = Random(AppBrushGrain.seed);
    for (int i = 0; i < texelCount; i++) {
      final int offset = i * AppMath.bytesPerPixel;
      pixels[offset] = channelMax; // R
      pixels[offset + AppMath.one] = channelMax; // G
      pixels[offset + AppMath.two] = channelMax; // B
      pixels[offset + AppMath.bytesPerPixel - AppMath.one] = AppBrushGrain.minAlpha + random.nextInt(alphaRange); // A
    }

    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, size, size, ui.PixelFormat.rgba8888, completer.complete);
    _tile = await completer.future;
  }
}
