import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Extracts the dominant colors from a given [image].
///
/// Returns a list of [ColorUsage] objects, each representing a color and its
/// usage percentage in the image.
Future<List<ColorUsage>> getImageColors(final ui.Image image) async {
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return <ColorUsage>[];
  }

  final Uint8List pixels = byteData.buffer.asUint8List();
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
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  return byteData!.buffer.asUint8List();
}

/// Copies a [ui.Image] to the system clipboard as a PNG.
Future<void> copyImageToClipboard(final ui.Image image) async {
  final SystemClipboard? clipboard = SystemClipboard.instance;
  if (clipboard != null) {
    final DataWriterItem item = DataWriterItem(suggestedName: 'fpaint.png');
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    item.add(Formats.png(data!.buffer.asUint8List()));
    await clipboard.write(<DataWriterItem>[item]);
  } else {
    // showMessage(_notAvailableMessage);
  }
}

/// Retrieves an image from the clipboard.
///
/// Returns a [ui.Image] if an image is found on the clipboard, otherwise returns null.
Future<ui.Image?> getImageFromClipboard() async {
  final Uint8List? bytes = await Pasteboard.image;
  if (bytes != null) {
    try {
      return await fromBytesToImage(bytes);
    } catch (e) {
      debugPrint(e.toString());
    }
  }
  return null;
}

/// Checks if the clipboard contains an image.
///
/// Returns true if the clipboard contains an image, otherwise returns false.
Future<bool> clipboardHasImage() async {
  final Uint8List? bytes = await Pasteboard.image;
  return bytes != null;
}

/// Resizes a [ui.Image] to a new [Size].
///
/// The [image] parameter is the image to resize, and [newSize] is the desired size.
Future<ui.Image> resizeImage(final ui.Image image, final ui.Size newSize) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.high
    ..isAntiAlias = true;

  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, newSize.width, newSize.height),
    paint,
  );

  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(newSize.width.toInt(), newSize.height.toInt());
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

/// A utility class that debounces a function call.
class Debouncer {
  /// Creates a [Debouncer] with an optional [duration].
  /// Defaults to 1 second if no duration is provided.
  Debouncer([this.duration = const Duration(seconds: 1)]);

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
