import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:super_clipboard/super_clipboard.dart';

import 'color_helper.dart';

Future<List<ColorUsage>> getImageColors(final ui.Image image) async {
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return <ColorUsage>[];
  }

  final Uint8List pixels = byteData.buffer.asUint8List();
  final Map<int, int> colorCount = <int, int>{};
  final int length = pixels.length;
  final int totalPixels = length ~/ 4;

  // Count color occurrences using packed ARGB integer
  for (int i = 0; i < length; i += 4) {
    final int alpha = pixels[i + 3];
    if (alpha > 0) {
      final int packedColor = (alpha << 24) |
          (pixels[i] << 16) |
          (pixels[i + 1] << 8) |
          pixels[i + 2];
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
    (final ColorUsage a, final ColorUsage b) =>
        b.percentage.compareTo(a.percentage),
  );

  if (colorUsages.length <= 20) {
    return colorUsages;
  }

  // Take top 20 colors
  return colorUsages.sublist(0, 20);
}

Future<ui.Image> fromBytesToImage(final Uint8List list) async {
  // Decode the image
  final ui.Codec codec = await ui.instantiateImageCodec(list);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();

  return frameInfo.image;
}

Future<Uint8List?> convertImageToUint8List(final ui.Image image) async {
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  return byteData!.buffer.asUint8List();
}

Future<List<String>> imageToListToString(final ui.Image image) async {
  final Uint8List? data = await convertImageToUint8List(image);
  return imageBytesListToString(data!, image.width);
}

List<String> imageBytesListToString(final Uint8List bytes, final int width) {
  final int length = bytes.length;
  final List<String> rows = <String>[];

  for (int i = 0; i < length; i += 4 * width) {
    final List<String> row = <String>[];
    for (int j = 0; j < width * 4; j += 4) {
      final int index = i + j;
      if (index + 3 < length) {
        final int alpha = bytes[index + 3];
        final int red = bytes[index];
        final int green = bytes[index + 1];
        final int blue = bytes[index + 2];
        row.add('${red.toRadixString(16).padLeft(2, '0')}'
            '${green.toRadixString(16).padLeft(2, '0')}'
            '${blue.toRadixString(16).padLeft(2, '0')}'
            '${alpha.toRadixString(16).padLeft(2, '0')}');
      }
    }
    rows.add(row.join('|'));
  }

  return rows;
}

Future<ui.Image> createImageFromBytes({
  required final Uint8List bytes,
  required final int width,
  required final int height,
}) async {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bytes,
    width,
    height,
    ui.PixelFormat.rgba8888,
    (final ui.Image img) {
      completer.complete(img);
    },
  );
  return completer.future;
}

Future<void> copyImageBase64(final Uint8List imageBytes) async {
  final String base64String = base64Encode(imageBytes);
  final ClipboardData clipboardData =
      ClipboardData(text: 'data:image/png;base64,$base64String');
  await Clipboard.setData(clipboardData);
}

Future<void> copyImageToClipboard(final ui.Image image) async {
  final SystemClipboard? clipboard = SystemClipboard.instance;
  if (clipboard != null) {
    final DataWriterItem item = DataWriterItem(suggestedName: 'fpaint.png');
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    item.add(Formats.png(data!.buffer.asUint8List()));
    await clipboard.write(<DataWriterItem>[item]);
  } else {
    // showMessage(_notAvailableMessage);
  }
}

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

Future<ui.Image> resizeImage(final ui.Image image, final Size newSize) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.high
    ..isAntiAlias = true;

  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(0, 0, newSize.width, newSize.height),
    paint,
  );

  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(newSize.width.toInt(), newSize.height.toInt());
}

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
