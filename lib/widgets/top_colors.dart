import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// A widget that displays the top colors used in the application.
///
/// This widget takes a list of [ColorUsage] objects, which represent the
/// colors used in the application and their popularity. It then displays
/// these colors in a grid, sorted by hue and popularity. The user can
/// refresh the list of colors or select a color to trigger a callback.
///
/// The widget can be displayed in a minimal mode, which removes some
/// of the UI elements.
class TopColors extends StatelessWidget {
  const TopColors({
    super.key,
    required this.colorUsages,
    required this.onRefresh,
    required this.onColorPicked,
    this.minimal = false,
  });

  final List<ColorUsage> colorUsages;
  final VoidCallback onRefresh;
  final void Function(Color) onColorPicked;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final List<ColorUsage> sortedColors = sortColorByHueAndPopularity();

    List<Widget> colorPreviews = sortedColors
        .map(
          (final ColorUsage colorUsed) => ColorPreview(
            colorUsed: colorUsed,
            minimal: minimal,
            onPressed: () {
              onColorPicked(colorUsed.color);
            },
          ),
        )
        .toList();
    return Column(
      children: [
        if (minimal) const Divider(color: Colors.black),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!minimal) Text('Top ${colorUsages.length} colors'),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
            ),
          ],
        ),
        IntrinsicHeight(
          child: transparentPaperContainer(
            Padding(
              padding: EdgeInsets.all(minimal ? 0 : 4.0),
              child: Wrap(
                spacing: 1,
                runSpacing: 1,
                children: colorPreviews,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sorts the `colorUsages` list by hue and popularity.
  ///
  /// The colors are first grouped by hue similarity (using a 15-degree threshold).
  /// Each hue group is then sorted by percentage (descending) and saturation (ascending).
  /// Finally, the hue groups are sorted by their total percentage usage (descending).
  ///
  /// The resulting list of `ColorUsage` objects is sorted by hue and popularity, with the most popular colors appearing first.
  List<ColorUsage> sortColorByHueAndPopularity() {
    Map<int, List<ColorUsage>> groupedByHue = {};

    // Group colors by hue similarity (using a 15-degree threshold)
    for (final ColorUsage usage in colorUsages) {
      double hue = HSVColor.fromColor(usage.color).hue;
      int hueKey = (hue / 15).round() * 15; // Grouping by 15-degree steps

      groupedByHue.putIfAbsent(hueKey, () => []);
      groupedByHue[hueKey]!.add(usage);
    }

    // Sort each hue group by percentage (descending), then by hue (ascending)
    for (final List<ColorUsage> group in groupedByHue.values) {
      group.sort((a, b) {
        int percentageComparison = b.percentage.compareTo(a.percentage);
        if (percentageComparison != 0) {
          return percentageComparison;
        }
        double saturationA = HSVColor.fromColor(a.color).saturation;
        double saturationB = HSVColor.fromColor(b.color).saturation;
        return saturationB
            .compareTo(saturationA); // Secondary sort by saturation
      });
    }

    // Sort hue groups by total percentage usage (descending)
    List<List<ColorUsage>> sortedGroups = groupedByHue.values.toList();
    sortedGroups.sort((a, b) {
      double totalA = a.fold(0, (sum, item) => sum + item.percentage);
      double totalB = b.fold(0, (sum, item) => sum + item.percentage);
      return totalB.compareTo(totalA);
    });

    // Flatten the sorted groups into a final sorted list
    return sortedGroups.expand((group) => group).toList();
  }
}
