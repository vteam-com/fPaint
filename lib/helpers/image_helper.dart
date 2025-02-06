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
  final Map<ui.Color, int> colorCount = {};

  // Count color occurrences
  for (int i = 0; i < pixels.length; i += 4) {
    final int alpha = pixels[i + 3];
    if (alpha == 0) {
      // discard true transparent color
    } else {
      final ui.Color color = ui.Color.fromARGB(
        alpha,
        pixels[i],
        pixels[i + 1],
        pixels[i + 2],
      );

      colorCount[color] = (colorCount[color] ?? 0) + 1;
    }
  }

  final int totalPixels = pixels.length ~/ 4;

  // Convert to percentage
  final List<ColorUsage> colorUsages = colorCount.entries.map((entry) {
    return ColorUsage(entry.key, (entry.value / totalPixels));
  }).toList();

  // Sort by highest percentage
  colorUsages.sort((a, b) => b.percentage.compareTo(a.percentage));

  if (colorUsages.length <= 10) {
    return colorUsages;
  } else {
    // Keep only top 10%
    final int topCount = (colorUsages.length * 0.1).ceil();
    return colorUsages.take(topCount).toList();
  }
}
