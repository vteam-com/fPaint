import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';

class ColorPreview extends StatelessWidget {
  const ColorPreview({
    super.key,
    required this.colorUsed,
    required this.onPressed,
  });
  final ColorUsage colorUsed;
  final GestureTapCallback onPressed;

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
            border: Border.all(color: Colors.grey),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: [
              Positioned(
                left: 0,
                child: Container(
                  width: 10,
                  height: 50,
                  color: Colors.white,
                ),
              ),
              Positioned(
                right: 0,
                child: Container(
                  width: 10,
                  height: 50,
                  color: Colors.black,
                ),
              ),
              Positioned(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorUsed.color,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
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
