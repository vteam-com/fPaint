import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// Displays a row of color previews at the top of the screen, allowing the user to select a color for the current tool.
///
/// The [TopColors] widget displays a row of [ColorPreview] widgets, each representing a [ColorUsage] in the provided [colors] list.
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
    required this.colors,
    required this.onRefresh,
    this.showTitle = true,
  });

  final List<ColorUsage> colors;
  final VoidCallback onRefresh;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final AppModel appModel = AppModel.of(context);
    List<Widget> colorPreviews = colors
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
            if (showTitle) Text('Top ${colors.length} colors'),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
            ),
          ],
        ),
        IntrinsicHeight(
          child: Stack(
            children: [
              const TransparentPaper(patternSize: 4),
              Container(
                alignment: Alignment.center,
                child: Wrap(
                  children: colorPreviews,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
