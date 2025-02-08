import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// Displays a row of color previews at the top of the screen, allowing the user to select a color for the current tool.
///
/// The [TopColors] widget displays a row of [ColorPreview] widgets, each representing a [ColorUsage] in the provided [colorUsages] list.
/// When a color preview is tapped, the [AppModel]'s [fillColor] or [brushColor] is updated based on the current selected tool.
/// The widget also includes a refresh button to trigger the [onRefresh] callback.
///
/// Example usage:
///
/// TopColors(
///   colors: appModel.topColors,
///   onRefresh: () => appModel.refreshTopColors(),
/// )
///

class TopColors extends StatelessWidget {
  const TopColors({
    super.key,
    required this.colorUsages,
    required this.onRefresh,
    this.showTitle = true,
  });

  final List<ColorUsage> colorUsages;
  final VoidCallback onRefresh;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final AppModel appModel = AppModel.of(context);

    final List<ColorUsage> sortedColors = sortColorByHueAndPopularity();

    List<Widget> colorPreviews = sortedColors
        .map(
          (final ColorUsage colorUsed) => ColorPreview(
            colorUsed: colorUsed,
            onPressed: () {
              (appModel.selectedTool == Tools.rectangle ||
                      appModel.selectedTool == Tools.circle ||
                      appModel.selectedTool == Tools.fill)
                  ? appModel.fillColor = colorUsed.color
                  : appModel.brushColor = colorUsed.color;
            },
          ),
        )
        .toList();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showTitle) Text('Top ${colorUsages.length} colors'),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
            ),
          ],
        ),
        IntrinsicHeight(
          child: transparentPaperContainer(
            Padding(
              padding: const EdgeInsets.all(4.0),
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
