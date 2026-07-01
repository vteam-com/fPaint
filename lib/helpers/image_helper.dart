import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:logging/logging.dart';
import 'package:pasteboard/pasteboard.dart';

final Logger _log = Logger(logNameImageHelper);

Uint8List? _sessionClipboardImageBytes;

/// Extracts pixel bytes from [image] using the requested [format].
Future<Uint8List?> extractImagePixels(
  final ui.Image image, {
  final ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba,
}) async {
  final ByteData? byteData = await image.toByteData(format: format);
  return byteData?.buffer.asUint8List();
}

/// Renders drawing commands into a new [ui.Image] with the given dimensions.
Future<ui.Image> renderCanvasImage({
  required final int width,
  required final int height,
  required final void Function(ui.Canvas) draw,
}) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  draw(canvas);
  return recorder.endRecording().toImage(width, height);
}

/// Renders drawing commands into a new [ui.Image] synchronously.
///
/// Mirrors [renderCanvasImage] for callers on synchronous paint/export paths
/// that need the image without awaiting.
ui.Image renderCanvasImageSync({
  required final int width,
  required final int height,
  required final void Function(ui.Canvas) draw,
}) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  draw(canvas);
  return recorder.endRecording().toImageSync(width, height);
}

/// Creates a [ui.Image] from straight RGBA pixel data.
Future<ui.Image> imageFromPixels(
  final Uint8List pixels,
  final int width,
  final int height,
) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

/// Creates a [ui.Image] from straight RGBA pixel data via [ui.decodeImageFromPixels].
///
/// The [ui.ImageDescriptor.raw] + `instantiateCodec` path is pathologically slow
/// for large raster buffers on Impeller (multi-second for ~1 MP). This direct
/// decode path avoids the codec abstraction and uploads the texture directly.
Future<ui.Image> imageFromPixelsDecode(
  final Uint8List pixels,
  final int width,
  final int height,
) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// Extracts the dominant colors from a given [image].
///
/// Returns a list of [ColorUsage] objects, each representing a color and its
/// usage percentage in the image.
Future<List<ColorUsage>> getImageColors(final ui.Image image) async {
  final Uint8List? pixels = await extractImagePixels(image);
  if (pixels == null) {
    return <ColorUsage>[];
  }
  final Map<int, int> colorCount = <int, int>{};
  final int length = pixels.length;
  final int totalPixels = length ~/ AppMath.bytesPerPixel;

  // Count color occurrences using packed ARGB integer
  for (int i = 0; i < length; i += AppMath.bytesPerPixel) {
    final int alpha = pixels[i + 3];
    if (alpha > 0) {
      final int packedColor = (alpha << 24) | (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
      colorCount[packedColor] = (colorCount[packedColor] ?? 0) + 1;
    }
  }

  // Convert to ColorUsage list with pre-allocated capacity
  final List<ColorUsage> colorUsages = List<ColorUsage>.filled(
    colorCount.length,
    ColorUsage(const ui.Color(0x00000000), 0),
  );

  int index = 0;
  colorCount.forEach((final int packedColor, final int count) {
    final ui.Color color = ui.Color(packedColor);
    colorUsages[index++] = ColorUsage(color, count / totalPixels);
  });

  // Sort in-place
  colorUsages.sort(
    (final ColorUsage a, final ColorUsage b) => b.percentage.compareTo(a.percentage),
  );

  if (colorUsages.length <= AppLimits.topColorCount) {
    return colorUsages;
  }

  // Take top 20 colors
  return colorUsages.sublist(0, AppLimits.topColorCount);
}

/// Converts a [Uint8List] of image data to a [ui.Image].
///
/// The [Uint8List] should contain the raw bytes of the image.
Future<ui.Image> fromBytesToImage(final Uint8List list) async {
  // Decode the image
  final ui.Codec codec = await ui.instantiateImageCodec(list);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();

  return frameInfo.image;
}

/// Converts a [ui.Image] to a [Uint8List] of raw RGBA data.
Future<Uint8List?> convertImageToUint8List(final ui.Image image) async {
  return extractImagePixels(
    image,
    format: ui.ImageByteFormat.rawStraightRgba,
  );
}

/// Copies a [ui.Image] to the system clipboard as a PNG.
Future<void> copyImageToClipboard(final ui.Image image) async {
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) {
    return;
  }

  final Uint8List pngBytes = data.buffer.asUint8List();
  _sessionClipboardImageBytes = pngBytes;
  await copyImageBytesToClipboard(pngBytes);
}

/// Copies PNG [imageBytes] to the system clipboard.
Future<void> copyImageBytesToClipboard(final Uint8List imageBytes) async {
  _sessionClipboardImageBytes = imageBytes;
  try {
    await Pasteboard.writeImage(imageBytes).timeout(AppDefaults.clipboardAccessTimeout);
  } catch (e) {
    _log.warning('Failed to copy image to clipboard: $e');
  }
}

/// Retrieves an image from the clipboard.
///
/// Returns a [ui.Image] if an image is found on the clipboard, otherwise returns null.
Future<ui.Image?> getImageFromClipboard() async {
  Uint8List? bytes;

  try {
    bytes = await Pasteboard.image.timeout(AppDefaults.clipboardAccessTimeout);
  } catch (e) {
    _log.warning('Failed to retrieve image from clipboard: $e');
  }

  bytes ??= _sessionClipboardImageBytes;

  if (bytes != null) {
    try {
      return await fromBytesToImage(bytes);
    } catch (e) {
      _log.severe('Failed to decode clipboard image', e);
    }
  }
  return null;
}

/// Checks if the clipboard contains an image.
///
/// Returns true if the clipboard contains an image, otherwise returns false.
Future<bool> clipboardHasImage() async {
  try {
    final Uint8List? bytes = await Pasteboard.image.timeout(AppDefaults.clipboardAccessTimeout);
    return bytes != null || _sessionClipboardImageBytes != null;
  } catch (e) {
    _log.warning('Failed to check clipboard for image: $e');
    return _sessionClipboardImageBytes != null;
  }
}

/// Box-average downscale of a straight-RGBA buffer from [srcWidth]x[srcHeight]
/// to [dstWidth]x[dstHeight].
///
/// A cheap CPU pass that shrinks a pixel buffer before a (slow) GPU upload; the
/// result is GPU-upscaled back for display. Each destination pixel averages the
/// source pixels that map into it, so soft content (smudge/blur) loses no
/// perceptible detail.
Uint8List downsampleRgbaBox(
  final Uint8List src,
  final int srcWidth,
  final int srcHeight,
  final int dstWidth,
  final int dstHeight,
) {
  final Uint8List out = Uint8List(dstWidth * dstHeight * AppMath.bytesPerPixel);
  for (int dy = AppMath.zero; dy < dstHeight; dy++) {
    final int sy0 = (dy * srcHeight) ~/ dstHeight;
    final int sy1 = math.max(sy0 + AppMath.one, ((dy + AppMath.one) * srcHeight) ~/ dstHeight);
    for (int dx = AppMath.zero; dx < dstWidth; dx++) {
      final int sx0 = (dx * srcWidth) ~/ dstWidth;
      final int sx1 = math.max(sx0 + AppMath.one, ((dx + AppMath.one) * srcWidth) ~/ dstWidth);
      int r = AppMath.zero, g = AppMath.zero, b = AppMath.zero, a = AppMath.zero, count = AppMath.zero;
      for (int sy = sy0; sy < sy1 && sy < srcHeight; sy++) {
        int si = ((sy * srcWidth) + sx0) * AppMath.bytesPerPixel;
        for (int sx = sx0; sx < sx1 && sx < srcWidth; sx++) {
          r += src[si + AppMath.rgbaRedOffset];
          g += src[si + AppMath.rgbaGreenOffset];
          b += src[si + AppMath.rgbaBlueOffset];
          a += src[si + AppMath.rgbaAlphaOffset];
          count++;
          si += AppMath.bytesPerPixel;
        }
      }
      if (count == AppMath.zero) {
        count = AppMath.one;
      }
      final int oi = ((dy * dstWidth) + dx) * AppMath.bytesPerPixel;
      out[oi + AppMath.rgbaRedOffset] = r ~/ count;
      out[oi + AppMath.rgbaGreenOffset] = g ~/ count;
      out[oi + AppMath.rgbaBlueOffset] = b ~/ count;
      out[oi + AppMath.rgbaAlphaOffset] = a ~/ count;
    }
  }
  return out;
}

/// Flips an [image] horizontally or vertically.
///
/// When [isHorizontal] is `true` the image is mirrored left ↔ right;
/// otherwise it is mirrored top ↔ bottom.
Future<ui.Image> flipImage(
  final ui.Image image, {
  required final bool isHorizontal,
}) async {
  final double w = image.width.toDouble();
  final double h = image.height.toDouble();
  return renderCanvasImage(
    width: w.toInt(),
    height: h.toInt(),
    draw: (final ui.Canvas canvas) {
      if (isHorizontal) {
        canvas.translate(w, 0);
        canvas.scale(-1, 1);
      } else {
        canvas.translate(0, h);
        canvas.scale(1, -1);
      }
      canvas.drawImage(image, ui.Offset.zero, ui.Paint());
    },
  );
}

/// Rotates an [image] 90 degrees clockwise.
///
/// The returned image has its width and height swapped.
Future<ui.Image> rotateImage90(final ui.Image image) async {
  final double w = image.width.toDouble();
  final double h = image.height.toDouble();
  return renderCanvasImage(
    width: h.toInt(),
    height: w.toInt(),
    draw: (final ui.Canvas canvas) {
      // Rotate 90° CW: translate to new width (old height), then rotate.
      canvas.translate(h, 0);
      canvas.rotate(math.pi / AppMath.pair);
      canvas.drawImage(image, ui.Offset.zero, ui.Paint());
    },
  );
}

/// Crops a [ui.Image] to a specified [Rect].
///
/// The [image] parameter is the image to crop, and [rect] is the rectangle to crop to.
ui.Image cropImage(final ui.Image image, final ui.Rect rect) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);

  final ui.Rect srcRect = ui.Rect.fromLTWH(
    rect.left,
    rect.top,
    rect.width,
    rect.height,
  );

  final ui.Rect dstRect = ui.Rect.fromLTWH(0, 0, rect.width, rect.height);

  canvas.drawImageRect(image, srcRect, dstRect, ui.Paint());

  final ui.Picture picture = recorder.endRecording();
  return picture.toImageSync(rect.width.toInt(), rect.height.toInt());
}

/// Returns the tight bounding box of non-transparent pixels in [image].
///
/// Returns `null` when the image is fully transparent.
Future<ui.Rect?> getNonTransparentBounds(final ui.Image image) async {
  final Uint8List? pixels = await extractImagePixels(image);
  if (pixels == null) {
    return null;
  }
  final int width = image.width;
  final int height = image.height;

  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;

  for (int y = 0; y < height; y++) {
    final int rowStart = y * width * AppMath.bytesPerPixel;
    for (int x = 0; x < width; x++) {
      final int alphaIndex = rowStart + (x * AppMath.bytesPerPixel) + 3;
      if (pixels[alphaIndex] > 0) {
        if (x < minX) {
          minX = x;
        }
        if (y < minY) {
          minY = y;
        }
        if (x > maxX) {
          maxX = x;
        }
        if (y > maxY) {
          maxY = y;
        }
      }
    }
  }

  if (maxX < minX || maxY < minY) {
    return null;
  }

  return ui.Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    (maxX + 1).toDouble(),
    (maxY + 1).toDouble(),
  );
}

/// A utility class that debounces a function call.
class Debouncer {
  /// Creates a [Debouncer] with an optional [duration].
  /// Defaults to [AppDefaults.debounceDuration] if no duration is provided.
  Debouncer([this.duration = AppDefaults.debounceDuration]);

  final Duration duration;
  Timer? _timer;

  /// Calls the [callback] after the specified [duration].
  /// If the method is called again before the duration elapses,
  /// the previous timer is canceled and a new one is started.
  void run(final VoidCallback callback) {
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer(duration, callback); // Start a new timer
  }

  /// Cancels the current timer if it is active.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
