import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/widgets/transparent_background.dart';

class MyColorPicker extends StatefulWidget {
  const MyColorPicker({
    required this.color,
    required this.onColorChanged,
    super.key,
  });

  final Color color;
  final Function(Color) onColorChanged;

  @override
  State<MyColorPicker> createState() => _MyColorPickerState();
}

class _MyColorPickerState extends State<MyColorPicker> {
  /// From 0.0% to 1.0% 0%=Black 100%=White
  late double brightness;

  /// From 0 to 360
  late double hue;

  /// From 0.0 to 1.0
  late double alpha;

  @override
  void didUpdateWidget(covariant MyColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    fromInputColorToHueBrightnessAndAlpha();
  }

  @override
  void initState() {
    super.initState();
    fromInputColorToHueBrightnessAndAlpha();
  }

  @override
  Widget build(BuildContext context) {
    const maxHue = 359.7;

    if (hue > maxHue) {
      hue = maxHue;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.black,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7), // Same radius as container
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 30,
              child: CustomPaint(
                painter: HueGradientPainter(),
                child: Slider(
                  value: hue,
                  min: 0,
                  max: maxHue,
                  divisions: 360 * 2,
                  label: hue.floor().toString(),
                  onChanged: (double value) {
                    setState(() {
                      hue = value;
                      if (brightness == 0 || brightness == 1) {
                        brightness = 0.5;
                      }
                      widget.onColorChanged(hsvToColor(hue, brightness, alpha));
                    });
                  },
                ),
              ),
            ),
            SizedBox(
              height: 30,
              child: CustomPaint(
                painter: BrightnessGradientPainter(hue: hue),
                child: Slider(
                  value: brightness,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  label: (brightness * 100).round().toString(),
                  onChanged: (double value) {
                    setState(() {
                      brightness = value;
                      widget.onColorChanged(hsvToColor(hue, brightness, alpha));
                    });
                  },
                ),
              ),
            ),
            SizedBox(
              height: 30,
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  const TransparentPaper(patternSize: 4),
                  CustomPaint(
                    painter: AlphaGradientPainter(hue: hue, brightness: brightness),
                    child: Slider(
                      value: alpha,
                      min: 0,
                      max: 1,
                      divisions: 100,
                      label: (alpha * 100).round().toString(),
                      onChanged: (double value) {
                        setState(() {
                          alpha = value;
                          widget.onColorChanged(
                            hsvToColor(hue, brightness, alpha),
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void fromInputColorToHueBrightnessAndAlpha() {
    final bothValues = getHueAndBrightnessFromColor(widget.color);
    hue = bothValues.first;
    brightness = bothValues.second;
    alpha = widget.color.a.toDouble();
  }
}

class HueGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const List<Color> colors = [
      Color.fromRGBO(255, 0, 0, 1), // 1 Red
      Color.fromRGBO(255, 255, 0, 1), // 2 Yellow
      Color.fromRGBO(0, 255, 0, 1), // 3 Green

      Color.fromRGBO(0, 255, 255, 1), // 4 Cyan

      Color.fromRGBO(0, 0, 255, 1), // 5 Blue
      Color.fromRGBO(255, 0, 255, 1), // 6 Purple
      Color.fromRGBO(255, 0, 0, 1), // 7 Red
    ];

    Gradient gradient = LinearGradient(
      colors: colors,
      stops: calculateSpread(0, 1, colors.length),
    );

    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class BrightnessGradientPainter extends CustomPainter {
  BrightnessGradientPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Gradient gradient = LinearGradient(
      colors: [
        HSLColor.fromAHSL(1.0, hue, 1.0, 0.0).toColor(), // Black
        HSLColor.fromAHSL(1.0, hue, 1.0, 0.5).toColor(), // Middle lightness
        HSLColor.fromAHSL(1.0, hue, 1.0, 1.0).toColor(), // White
      ],
    );

    final Paint paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // We want to repaint when the hue changes
  }
}

class AlphaGradientPainter extends CustomPainter {
  AlphaGradientPainter({required this.hue, required this.brightness});

  final double hue;
  final double brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Gradient gradient = LinearGradient(
      colors: [
        hsvToColor(hue, brightness, 0.0), // Transparent
        hsvToColor(hue, brightness, 1.0), // Opaque
      ],
    );

    final Paint paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // We want to repaint when the hue or brightness changes
  }
}

/// Displays a color picker dialog with the given title, initial color, and callback for the selected color.
///
/// The color picker dialog is displayed using the [showDialog] function, and includes a [ColorPicker] widget
/// that allows the user to select a color. The selected color is passed to the [onSelectedColor] callback.
///
/// Parameters:
/// - `context`: The [BuildContext] used to display the dialog.
/// - `title`: The title of the color picker dialog.
/// - `color`: The initial color to be displayed in the color picker.
/// - `onSelectedColor`: A callback that is called when the user selects a color. The selected color is passed as an argument.
void showColorPicker({
  required final BuildContext context,
  required final String title,
  required final Color color,
  required final ValueChanged<Color> onSelectedColor,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: color,
            onColorChanged: (Color color) {
              onSelectedColor(color);
            },
            pickersEnabled: {
              ColorPickerType.wheel: true,
              ColorPickerType.primary: true,
              ColorPickerType.accent: true,
            },
            showColorCode: true,
          ),
        ),
      );
    },
  );
}

Color hsvToColor(final double hue, final double brightness, final double alpha) {
  final hslColor = HSLColor.fromAHSL(alpha, hue, 1.0, brightness);
  return hslColor.toColor();
}
