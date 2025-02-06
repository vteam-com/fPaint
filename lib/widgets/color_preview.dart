import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/models/app_model.dart';

class ColorPreview extends StatelessWidget {
  const ColorPreview({
    super.key,
    required this.colorUsed,
  });
  final ColorUsage colorUsed;

  @override
  Widget build(BuildContext context) {
    AppModel appModel = AppModel.get(context);

    final List<String> components = getColorComponentsAsHex(colorUsed.color);
    final String alpha = components[0];
    final String red = components[1];
    final String green = components[2];
    final String blue = components[3];

    return Tooltip(
      message:
          '${colorToHexString(colorUsed.color, gapForAlpha: true)}\n${colorUsed.toStringPercentage(3)}',
      child: GestureDetector(
        onTap: () {
          appModel.brushColor = colorUsed.color;
        },
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
