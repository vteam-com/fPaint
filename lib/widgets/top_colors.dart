import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/transparent_background.dart';

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
    List<Widget> colorPreviews = colors
        .map((final ColorUsage colorUsed) => ColorPreview(colorUsed: colorUsed))
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
