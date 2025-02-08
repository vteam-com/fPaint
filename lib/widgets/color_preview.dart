import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/widgets/transparent_background.dart';

Widget colorPreviewWithTransparentPaper(
  Color color,
  GestureTapCallback onPressed,
) {
  return SizedBox(
    height: 90,
    width: 53,
    child: transparentPaperContainer(
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: ColorPreview(
          colorUsed: ColorUsage(color, 1),
          onPressed: onPressed,
          border: false,
        ),
      ),
    ),
  );
}

/// Displays a preview of a color with its hexadecimal components.
///
/// The [ColorPreview] widget displays a square preview of a color, along with its
/// hexadecimal components (alpha, red, green, blue) in a centered text. The
/// preview also includes a white bar on the left side and a black bar on the
/// right side to help visualize the color.
///
/// The widget can be tapped to trigger the provided [onPressed] callback.
/// The tooltip displays the full hexadecimal color code and the usage percentage
/// (if the color usage is less than 100%).

class ColorPreview extends StatelessWidget {
  const ColorPreview({
    super.key,
    required this.colorUsed,
    required this.onPressed,
    this.border = true,
  });
  final ColorUsage colorUsed;
  final GestureTapCallback onPressed;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final List<String> components = getColorComponentsAsHex(colorUsed.color);
    final String alpha = components[0];
    final String red = components[1];
    final String green = components[2];
    final String blue = components[3];

    String usageNumber = '';
    if (colorUsed.percentage < 1) {
      usageNumber = '\nUsage ${colorUsed.toStringPercentage(1)}';
    }

    return Tooltip(
      message: '${colorToHexString(colorUsed.color)}$usageNumber',
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 60,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: border ? Border.all(color: Colors.grey) : null,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: [
              //--------------------------------
              //
              // Left Side White Rectangle
              //
              Positioned(
                left: 0,
                child: Container(
                  width: 10,
                  height: 50,
                  color: Colors.white,
                ),
              ),
              //--------------------------------
              //
              // Right Side Black Rectangle
              //
              Positioned(
                right: 0,
                child: Container(
                  width: 10,
                  height: 50,
                  color: Colors.black,
                ),
              ),

              //--------------------------------
              // Rectangle of the final color
              //

              Positioned(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorUsed.color,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),

              //--------------------------------
              // Hex color
              //
              Center(
                child: Text(
                  textAlign: TextAlign.center,
                  '$alpha\n$red\n$green\n$blue',
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
      ),
    );
  }
}
