import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:fpaint/helpers/color_helper.dart';

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
