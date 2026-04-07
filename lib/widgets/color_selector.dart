// ignore: fcheck_one_class_per_file
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// A widget that allows the user to select a color using HSV sliders.
class ColorSelector extends StatefulWidget {
  /// Creates a [ColorSelector].
  const ColorSelector({
    required this.color,
    required this.onColorChanged,
    super.key,
  });

  /// The current color.
  final Color color;

  /// A callback that is called when the selected color changes.
  final void Function(Color) onColorChanged;

  @override
  State<ColorSelector> createState() => _ColorSelectorState();
}

class _ColorSelectorState extends State<ColorSelector> {
  /// From 0.0 to 1.0
  late double alpha;

  /// From 0.0% to 1.0% 0%=Black 100%=White
  late double brightness;

  /// From 0 to 360
  late double hue;

  @override
  void initState() {
    super.initState();
    fromInputColorToHueBrightnessAndAlpha();
  }

  @override
  void didUpdateWidget(covariant final ColorSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    fromInputColorToHueBrightnessAndAlpha();
  }

  @override
  Widget build(final BuildContext context) {
    const double maxHue = 359.7;

    if (hue > maxHue) {
      hue = maxHue;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: Colors.grey,
          width: AppStroke.thin,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppStroke.thin),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.sm - AppStroke.thin), // Same radius as container
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: AppLayout.sliderHeight,
                child: CustomPaint(
                  painter: HueGradientPainter(),
                  child: Slider(
                    value: hue,
                    min: 0,
                    max: maxHue,
                    divisions: AppLimits.hueDivisions * AppMath.pair,
                    label: hue.floor().toString(),
                    onChanged: (final double value) {
                      setState(() {
                        hue = value;
                        if (brightness == 0 || brightness == 1) {
                          brightness = AppVisual.half;
                        }
                        widget.onColorChanged(hsvToColor(hue, brightness, alpha));
                      });
                    },
                  ),
                ),
              ),
              SizedBox(
                height: AppLayout.sliderHeight,
                child: CustomPaint(
                  painter: BrightnessGradientPainter(hue: hue),
                  child: Slider(
                    value: brightness,
                    min: 0,
                    max: 1,
                    divisions: AppLimits.sliderDivisions,
                    label: (brightness * AppLimits.percentMax).round().toString(),
                    onChanged: (final double value) {
                      setState(() {
                        brightness = value;
                        widget.onColorChanged(hsvToColor(hue, brightness, alpha));
                      });
                    },
                  ),
                ),
              ),
              SizedBox(
                height: AppLayout.sliderHeight,
                child: Stack(
                  alignment: AlignmentDirectional.center,
                  children: <Widget>[
                    const TransparentPaper(patternSize: AppMath.bytesPerPixel),
                    CustomPaint(
                      painter: AlphaGradientPainter(
                        hue: hue,
                        brightness: brightness,
                      ),
                      child: Slider(
                        value: alpha,
                        min: 0,
                        max: 1,
                        divisions: AppLimits.sliderDivisions,
                        label: (alpha * AppLimits.percentMax).round().toString(),
                        onChanged: (final double value) {
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
      ),
    );
  }

  /// Converts the input color to HSV values.
  void fromInputColorToHueBrightnessAndAlpha() {
    final HSLColor hslColor = HSLColor.fromColor(widget.color);

    // Extract hue, lightness, and alpha values
    hue = hslColor.hue;
    brightness = hslColor.lightness;
    alpha = widget.color.a;
  }
}

/// Paints a hue gradient on a canvas.
class HueGradientPainter extends CustomPainter {
  @override
  void paint(final Canvas canvas, final Size size) {
    const List<Color> colors = <Color>[
      Color.fromRGBO(255, 0, 0, 1), // 1 Red
      Color.fromRGBO(255, 255, 0, 1), // 2 Yellow
      Color.fromRGBO(0, 255, 0, 1), // 3 Green

      Color.fromRGBO(0, 255, 255, 1), // 4 Cyan

      Color.fromRGBO(0, 0, 255, 1), // 5 Blue
      Color.fromRGBO(255, 0, 255, 1), // 6 Purple
      Color.fromRGBO(255, 0, 0, 1), // 7 Red
    ];

    final Gradient gradient = LinearGradient(
      colors: colors,
      stops: calculateSpread(0, 1, colors.length),
    );

    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant final HueGradientPainter oldDelegate) {
    return false; // Hue gradient is static, never needs repaint based on properties.
  }
}

/// Paints a brightness gradient on a canvas.
class BrightnessGradientPainter extends CustomPainter {
  /// Creates a [BrightnessGradientPainter].
  BrightnessGradientPainter({required this.hue});

  /// The hue of the gradient.
  final double hue;

  @override
  void paint(final Canvas canvas, final Size size) {
    final Rect rect = Offset.zero & size;
    final Gradient gradient = LinearGradient(
      colors: <Color>[
        HSLColor.fromAHSL(1.0, hue, 1.0, 0.0).toColor(), // Black
        HSLColor.fromAHSL(1.0, hue, 1.0, AppVisual.half).toColor(), // Middle lightness
        HSLColor.fromAHSL(1.0, hue, 1.0, 1.0).toColor(), // White
      ],
    );

    final Paint paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant final BrightnessGradientPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

/// Paints an alpha gradient on a canvas.
class AlphaGradientPainter extends CustomPainter {
  /// Creates an [AlphaGradientPainter].
  AlphaGradientPainter({required this.hue, required this.brightness});

  /// The hue of the gradient.
  final double hue;

  /// The brightness of the gradient.
  final double brightness;

  @override
  void paint(final Canvas canvas, final Size size) {
    final Rect rect = Offset.zero & size;
    final Gradient gradient = LinearGradient(
      colors: <Color>[
        hsvToColor(hue, brightness, 0.0), // Transparent
        hsvToColor(hue, brightness, 1.0), // Opaque
      ],
    );

    final Paint paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant final AlphaGradientPainter oldDelegate) {
    return oldDelegate.hue != hue || oldDelegate.brightness != brightness;
  }
}

/// Converts HSV values to a Color.
Color hsvToColor(
  final double hue,
  final double brightness,
  final double alpha,
) {
  final HSLColor hslColor = HSLColor.fromAHSL(alpha, hue, 1.0, brightness);
  return hslColor.toColor();
}
