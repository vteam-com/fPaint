import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:super_clipboard/super_clipboard.dart';

import 'color_helper.dart';

Future<List<ColorUsage>> getImageColors(ui.Image image) async {
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return [];
  }

  final Uint8List pixels = byteData.buffer.asUint8List();
  final Map<int, int> colorCount = {};
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
  final List<ColorUsage> colorUsages = List.filled(
    colorCount.length,
    ColorUsage(const ui.Color(0x00000000), 0),
  );

  int index = 0;
  colorCount.forEach((final int packedColor, count) {
    final ui.Color color = ui.Color(packedColor);
    colorUsages[index++] = ColorUsage(color, count / totalPixels);
  });

  // Sort in-place
  colorUsages.sort((a, b) => b.percentage.compareTo(a.percentage));

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
  ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  return byteData!.buffer.asUint8List();
}

List<String> imageBytesListToString(Uint8List bytes, int width) {
  final int length = bytes.length;
  final List<String> rows = [];

  for (int i = 0; i < length; i += 4 * width) {
    final List<String> row = [];
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
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromPixels(
    bytes,
    width,
    height,
    ui.PixelFormat.rgba8888,
    (ui.Image img) {
      completer.complete(img);
    },
  );
  return completer.future;
}

Future<void> copyImageBase64(Uint8List imageBytes) async {
  final base64String = base64Encode(imageBytes);
  final clipboardData =
      ClipboardData(text: 'data:image/png;base64,$base64String');
  await Clipboard.setData(clipboardData);
}

Future<void> copyImageToClipboard(ui.Image image) async {
  final SystemClipboard? clipboard = SystemClipboard.instance;
  if (clipboard != null) {
    final DataWriterItem item = DataWriterItem(suggestedName: 'fpaint.png');
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    item.add(Formats.png(data!.buffer.asUint8List()));
    await clipboard.write([item]);
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
