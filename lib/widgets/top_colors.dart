import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/widgets/transparent_background.dart';

class TopColors extends StatelessWidget {
  const TopColors({super.key, required this.colors, required this.onRefresh});

  final List<ColorUsage> colors;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    List<Widget> colorPreviews = colors
        .map((final ColorUsage colorUsed) => colorPreview(colorUsed))
        .toList();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Top colors'),
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

Widget colorPreview(final ColorUsage colorUsed) {
  return Tooltip(
    message:
        '${colorToHexString(colorUsed.color, gapForAlpha: true)}\n${colorUsed.toStringPercentage(3)}',
    child: Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.all(4),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorUsed.color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Center(
            child: Text(
              colorUsed.toStringPercentage(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 9,
                color: colorUsed.color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
