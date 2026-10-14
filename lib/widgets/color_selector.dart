// ignore: fcheck_one_class_per_file
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/widgets/material_free.dart';
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
  void didUpdateWidget(covariant ColorSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    fromInputColorToHueBrightnessAndAlpha();
  }

  @override
  Widget build(BuildContext context) {
    const double maxHue = 359.7;

    if (hue > maxHue) {
      hue = maxHue;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppStroke.thin),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.small - AppStroke.thin), // Same radius as container
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: AppLayout.sliderHeight,
                child: CustomPaint(
                  painter: HueGradientPainter(),
                  child: AppSlider(
                    value: hue,
                    min: 0,
                    max: maxHue,
                    divisions: AppLimits.hueDivisions * AppMath.pair,
                    onChanged: (double value) {
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
                  child: AppSlider(
                    value: brightness,
                    min: 0,
                    max: 1,
                    divisions: AppLimits.sliderDivisions,
                    onChanged: (double value) {
                      setState(() {
                        brightness = value;
                        widget.onColorChanged(hsvToColor(hue, brightness, alpha));
                      });
                    },
                  ),
                ),
              ),
              AlphaGradientSlider(
                painter: AlphaGradientPainter(
                  hue: hue,
                  brightness: brightness,
                ),
                value: alpha,
                onChanged: (double value) {
                  setState(() {
                    alpha = value;
                    widget.onColorChanged(
                      hsvToColor(hue, brightness, alpha),
                    );
                  });
                },
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

/// A slider-height opacity slider: a checkerboard under [painter]'s
/// transparent-to-opaque strip, with an [AppSlider] for [value] (0..1) on top.
class AlphaGradientSlider extends StatelessWidget {
  /// Creates an [AlphaGradientSlider].
  const AlphaGradientSlider({
    super.key,
    required this.painter,
    required this.value,
    required this.onChanged,
  });

  /// Called with the new alpha (0..1) while the slider is dragged.
  final ValueChanged<double> onChanged;

  /// Paints the transparent-to-opaque gradient strip behind the slider.
  final CustomPainter painter;

  /// The current alpha, from 0 (transparent) to 1 (opaque).
  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppLayout.sliderHeight,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          const TransparentPaper(patternSize: AppMath.bytesPerPixel),
          CustomPaint(
            painter: painter,
            child: AppSlider(
              value: value,
              min: 0,
              max: 1,
              divisions: AppLimits.sliderDivisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fills its whole area with a left-to-right [LinearGradient] of [colors]
/// (optionally at [stops]); repaints only when the colors or stops change.
class LinearGradientStripPainter extends CustomPainter {
  /// Creates a [LinearGradientStripPainter].
  LinearGradientStripPainter({required this.colors, this.stops});

  /// The gradient colors, left to right.
  final List<Color> colors;

  /// Optional positions (0..1) of [colors]; evenly spread when null.
  final List<double>? stops;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Gradient gradient = LinearGradient(colors: colors, stops: stops);
    final Paint paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant LinearGradientStripPainter oldDelegate) {
    return !listEquals(oldDelegate.colors, colors) || !listEquals(oldDelegate.stops, stops);
  }
}

/// The fully saturated hue spectrum, red through every hue back to red.
const List<Color> _hueSpectrumColors = <Color>[
  Color.fromRGBO(255, 0, 0, 1), // 1 Red
  Color.fromRGBO(255, 255, 0, 1), // 2 Yellow
  Color.fromRGBO(0, 255, 0, 1), // 3 Green

  Color.fromRGBO(0, 255, 255, 1), // 4 Cyan

  Color.fromRGBO(0, 0, 255, 1), // 5 Blue
  Color.fromRGBO(255, 0, 255, 1), // 6 Purple
  Color.fromRGBO(255, 0, 0, 1), // 7 Red
];

/// Paints a hue gradient on a canvas.
class HueGradientPainter extends LinearGradientStripPainter {
  /// Creates a [HueGradientPainter].
  HueGradientPainter()
    : super(
        colors: _hueSpectrumColors,
        stops: calculateSpread(0, 1, _hueSpectrumColors.length),
      );
}

/// Paints a brightness gradient on a canvas.
class BrightnessGradientPainter extends LinearGradientStripPainter {
  /// Creates a [BrightnessGradientPainter].
  BrightnessGradientPainter({required this.hue})
    : super(
        colors: <Color>[
          HSLColor.fromAHSL(1.0, hue, 1.0, 0.0).toColor(), // Black
          HSLColor.fromAHSL(1.0, hue, 1.0, AppVisual.half).toColor(), // Middle lightness
          HSLColor.fromAHSL(1.0, hue, 1.0, 1.0).toColor(), // White
        ],
      );

  /// The hue of the gradient.
  final double hue;
}

/// Paints an alpha gradient on a canvas.
class AlphaGradientPainter extends LinearGradientStripPainter {
  /// Creates an [AlphaGradientPainter].
  AlphaGradientPainter({required this.hue, required this.brightness})
    : super(
        colors: <Color>[
          hsvToColor(hue, brightness, 0.0), // Transparent
          hsvToColor(hue, brightness, 1.0), // Opaque
        ],
      );

  /// The hue of the gradient.
  final double hue;

  /// The brightness of the gradient.
  final double brightness;
}

/// Converts HSV values to a Color.
Color hsvToColor(
  double hue,
  double brightness,
  double alpha,
) {
  final HSLColor hslColor = HSLColor.fromAHSL(alpha, hue, 1.0, brightness);
  return hslColor.toColor();
}
