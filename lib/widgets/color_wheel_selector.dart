import 'dart:math' as math;
import 'dart:ui' show BlendMode, FilterQuality, VertexMode, Vertices;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/transparent_background.dart';

enum _ColorWheelDragTarget {
  ring,
  triangle,
}

/// A widget that allows the user to select hue and saturation from a color wheel.
class ColorWheelSelector extends StatefulWidget {
  /// Creates a [ColorWheelSelector].
  const ColorWheelSelector({
    required this.color,
    required this.onColorChanged,
    super.key,
  });

  /// The currently selected color.
  final Color color;

  /// Called whenever the selected color changes.
  final ValueChanged<Color> onColorChanged;

  @override
  State<ColorWheelSelector> createState() => _ColorWheelSelectorState();
}

class _ColorWheelSelectorState extends State<ColorWheelSelector> {
  late double _alpha;
  _ColorWheelDragTarget? _dragTarget;
  late double _hue;
  late double _saturation;
  Offset? _triangleSelectionPoint;
  late double _value;
  @override
  void initState() {
    super.initState();
    _syncFromColor();
  }

  @override
  void didUpdateWidget(covariant final ColorWheelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.color != widget.color) {
      _syncFromColor();
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.medium,
      children: <Widget>[
        SizedBox(
          width: AppLayout.colorWheelDiameter,
          height: AppLayout.colorWheelDiameter,
          child: GestureDetector(
            key: Keys.colorPickerWheelSelector,
            behavior: HitTestBehavior.opaque,
            onPanDown: (final DragDownDetails details) {
              _dragTarget = _resolveDragTarget(details.localPosition);
              _updateFromLocalPosition(details.localPosition);
            },
            onPanStart: (final DragStartDetails details) {
              _dragTarget = _resolveDragTarget(details.localPosition);
              _updateFromLocalPosition(details.localPosition);
            },
            onPanUpdate: (final DragUpdateDetails details) {
              _updateFromLocalPosition(details.localPosition);
            },
            onPanEnd: (_) {
              _dragTarget = null;
            },
            onPanCancel: () {
              _dragTarget = null;
            },
            onTapDown: (final TapDownDetails details) {
              _dragTarget = _resolveDragTarget(details.localPosition);
              _updateFromLocalPosition(details.localPosition);
              _dragTarget = null;
            },
            child: CustomPaint(
              painter: _ColorWheelPainter(
                alpha: _alpha,
                hue: _hue,
                saturation: _saturation,
                triangleThumbCenterOverride: _triangleSelectionPoint,
                value: _value,
              ),
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
                painter: _WheelAlphaGradientPainter(
                  alpha: _alpha,
                  hue: _hue,
                  saturation: _saturation,
                  value: _value,
                ),
                child: AppSlider(
                  value: _alpha,
                  min: 0,
                  max: 1,
                  divisions: AppLimits.sliderDivisions,
                  onChanged: (final double value) {
                    setState(() {
                      _alpha = value;
                    });
                    _notifyColorChanged();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ({
    Offset blackVertex,
    Offset center,
    Offset colorVertex,
    double outerRadius,
    double ringInnerRadius,
    Offset whiteVertex,
  })
  get _currentWheelGeometry {
    return _buildWheelGeometry(
      const Size.square(AppLayout.colorWheelDiameter),
      _hue,
    );
  }

  void _notifyColorChanged() {
    widget.onColorChanged(
      HSVColor.fromAHSV(_alpha, _hue, _saturation, _value).toColor(),
    );
  }

  /// Resolves whether [localPosition] targets the hue ring or SV triangle.
  _ColorWheelDragTarget? _resolveDragTarget(final Offset localPosition) {
    final Size size = const Size.square(AppLayout.colorWheelDiameter);
    final ({
      Offset blackVertex,
      Offset center,
      Offset colorVertex,
      double outerRadius,
      double ringInnerRadius,
      Offset whiteVertex,
    })
    geometry = _buildWheelGeometry(size, _hue);
    final double distanceToCenter = (localPosition - geometry.center).distance;

    if (distanceToCenter <= geometry.outerRadius && distanceToCenter >= geometry.ringInnerRadius) {
      return _ColorWheelDragTarget.ring;
    }

    final ({double black, double color, double white})? weights = _triangleWeightsForPoint(
      point: localPosition,
      whiteVertex: geometry.whiteVertex,
      blackVertex: geometry.blackVertex,
      colorVertex: geometry.colorVertex,
    );

    if (weights == null) {
      return null;
    }

    return _ColorWheelDragTarget.triangle;
  }

  /// Synchronizes internal HSV values and triangle thumb position from the
  /// externally provided widget color.
  void _syncFromColor() {
    final HSVColor hsvColor = HSVColor.fromColor(widget.color);
    _alpha = widget.color.a;
    _hue = hsvColor.hue;
    _saturation = hsvColor.saturation;
    _value = hsvColor.value;
    _triangleSelectionPoint = _triangleBestPointForColor(
      blackVertex: _currentWheelGeometry.blackVertex,
      colorVertex: _currentWheelGeometry.colorVertex,
      hueColor: HSVColor.fromAHSV(AppVisual.full, _hue, AppVisual.full, AppVisual.full).toColor(),
      targetColor: HSVColor.fromAHSV(AppVisual.full, _hue, _saturation, _value).toColor(),
      whiteVertex: _currentWheelGeometry.whiteVertex,
    );
  }

  /// Updates hue/saturation/value based on pointer movement inside the active
  /// ring or triangle target.
  void _updateFromLocalPosition(final Offset localPosition) {
    final Size size = const Size.square(AppLayout.colorWheelDiameter);
    final ({
      Offset blackVertex,
      Offset center,
      Offset colorVertex,
      double outerRadius,
      double ringInnerRadius,
      Offset whiteVertex,
    })
    geometry = _buildWheelGeometry(size, _hue);
    final _ColorWheelDragTarget? target = _dragTarget ?? _resolveDragTarget(localPosition);

    if (target == null) {
      return;
    }

    if (target == _ColorWheelDragTarget.ring) {
      final Offset delta = localPosition - geometry.center;
      if (delta.distance == 0) {
        return;
      }

      setState(() {
        _hue = _normalizeDegrees(_radiansToDegrees(math.atan2(delta.dy, delta.dx)));
        _triangleSelectionPoint = _triangleBestPointForColor(
          blackVertex: _currentWheelGeometry.blackVertex,
          colorVertex: _currentWheelGeometry.colorVertex,
          hueColor: HSVColor.fromAHSV(AppVisual.full, _hue, AppVisual.full, AppVisual.full).toColor(),
          targetColor: HSVColor.fromAHSV(AppVisual.full, _hue, _saturation, _value).toColor(),
          whiteVertex: _currentWheelGeometry.whiteVertex,
        );
      });
      _notifyColorChanged();
      return;
    }

    final ({double black, double color, double white})? weights = _triangleWeightsForPoint(
      point: localPosition,
      whiteVertex: geometry.whiteVertex,
      blackVertex: geometry.blackVertex,
      colorVertex: geometry.colorVertex,
    );

    if (weights == null) {
      return;
    }

    final double selectedValue = (AppVisual.full - weights.black).clamp(0.0, AppVisual.full);
    final double selectedSaturation = selectedValue <= 0
        ? 0
        : (weights.color / selectedValue).clamp(0.0, AppVisual.full);
    final Offset selectedPoint = _trianglePointForWeights(
      blackVertex: geometry.blackVertex,
      colorVertex: geometry.colorVertex,
      weights: weights,
      whiteVertex: geometry.whiteVertex,
    );

    setState(() {
      _value = selectedValue;
      _saturation = selectedSaturation;
      _triangleSelectionPoint = selectedPoint;
    });

    _notifyColorChanged();
  }
}

class _ColorWheelPainter extends CustomPainter {
  const _ColorWheelPainter({
    required this.alpha,
    required this.hue,
    required this.saturation,
    required this.triangleThumbCenterOverride,
    required this.value,
  });

  final double alpha;
  final double hue;
  final double saturation;
  final Offset? triangleThumbCenterOverride;
  final double value;

  @override
  void paint(final Canvas canvas, final Size size) {
    final ({
      Offset blackVertex,
      Offset center,
      Offset colorVertex,
      double outerRadius,
      double ringInnerRadius,
      Offset whiteVertex,
    })
    geometry = _buildWheelGeometry(size, hue);
    final Rect outerRect = Rect.fromCircle(center: geometry.center, radius: geometry.outerRadius);
    final Rect innerRect = Rect.fromCircle(center: geometry.center, radius: geometry.ringInnerRadius);
    final Paint ringPaint = Paint()
      ..shader = const SweepGradient(
        colors: <Color>[
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ],
      ).createShader(outerRect);
    final Paint ringOutlinePaint = Paint()
      ..color = AppColors.grey600
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.thin
      ..isAntiAlias = true;
    final Path ringPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(outerRect)
      ..addOval(innerRect);
    canvas.drawPath(ringPath, ringPaint);
    canvas.drawCircle(geometry.center, geometry.outerRadius, ringOutlinePaint);
    canvas.drawCircle(geometry.center, geometry.ringInnerRadius, ringOutlinePaint);

    final Path trianglePath = Path()
      ..moveTo(geometry.blackVertex.dx, geometry.blackVertex.dy)
      ..lineTo(geometry.whiteVertex.dx, geometry.whiteVertex.dy)
      ..lineTo(geometry.colorVertex.dx, geometry.colorVertex.dy)
      ..close();
    final Color hueColor = HSVColor.fromAHSV(AppVisual.full, hue, AppVisual.full, AppVisual.full).toColor();
    final Paint trianglePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.drawVertices(
      Vertices(
        VertexMode.triangles,
        <Offset>[
          geometry.blackVertex,
          geometry.whiteVertex,
          geometry.colorVertex,
        ],
        colors: <Color>[
          AppColors.black,
          AppColors.white,
          hueColor,
        ],
      ),
      BlendMode.src,
      trianglePaint,
    );

    final Paint triangleBorderPaint = Paint()
      ..color = AppColors.grey400
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.thin
      ..isAntiAlias = true;
    canvas.drawPath(trianglePath, triangleBorderPaint);

    final double hueRadians = _degreesToRadians(hue);
    final double hueIndicatorRadius = geometry.ringInnerRadius + (AppLayout.colorWheelRingThickness / AppMath.pair);
    final Offset ringThumbCenter = Offset(
      geometry.center.dx + math.cos(hueRadians) * hueIndicatorRadius,
      geometry.center.dy + math.sin(hueRadians) * hueIndicatorRadius,
    );
    final ({double black, double color, double white}) weights = _triangleWeightsForHsv(
      saturation: saturation,
      value: value,
    );
    final Offset triangleThumbCenter =
        triangleThumbCenterOverride ??
        _trianglePointForWeights(
          blackVertex: geometry.blackVertex,
          colorVertex: geometry.colorVertex,
          weights: weights,
          whiteVertex: geometry.whiteVertex,
        );
    final double thumbRadius = AppLayout.colorWheelThumbDiameter / AppMath.pair;
    final Paint thumbPaint = Paint()
      ..color = HSVColor.fromAHSV(alpha, hue, saturation, value).toColor()
      ..style = PaintingStyle.fill;
    final Paint thumbShadowPaint = Paint()
      ..color = AppColors.grey700
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.emphasis;
    final Paint thumbBorderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.regular;

    canvas.drawCircle(triangleThumbCenter, thumbRadius, thumbPaint);
    canvas.drawCircle(triangleThumbCenter, thumbRadius, thumbShadowPaint);
    canvas.drawCircle(triangleThumbCenter, thumbRadius, thumbBorderPaint);
    canvas.drawCircle(ringThumbCenter, thumbRadius, thumbPaint);
    canvas.drawCircle(ringThumbCenter, thumbRadius, thumbShadowPaint);
    canvas.drawCircle(ringThumbCenter, thumbRadius, thumbBorderPaint);
  }

  @override
  bool shouldRepaint(covariant final _ColorWheelPainter oldDelegate) {
    return oldDelegate.alpha != alpha ||
        oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.triangleThumbCenterOverride != triangleThumbCenterOverride ||
        oldDelegate.value != value;
  }
}

class _WheelAlphaGradientPainter extends CustomPainter {
  const _WheelAlphaGradientPainter({
    required this.alpha,
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final double alpha;
  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(final Canvas canvas, final Size size) {
    final Rect rect = Offset.zero & size;
    final Gradient gradient = LinearGradient(
      colors: <Color>[
        HSVColor.fromAHSV(0, hue, saturation, value).toColor(),
        HSVColor.fromAHSV(alpha, hue, saturation, value).toColor(),
      ],
    );

    final Paint paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant final _WheelAlphaGradientPainter oldDelegate) {
    return oldDelegate.alpha != alpha ||
        oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.value != value;
  }
}

/// Computes wheel and triangle geometry for [size] at the given [hue].
({
  Offset blackVertex,
  Offset center,
  Offset colorVertex,
  double outerRadius,
  double ringInnerRadius,
  Offset whiteVertex,
})
_buildWheelGeometry(final Size size, final double hue) {
  final double outerRadius = math.min(size.width, size.height) / AppMath.pair;
  final Offset center = Offset(size.width / AppMath.pair, size.height / AppMath.pair);
  final double ringInnerRadius = outerRadius - AppLayout.colorWheelRingThickness;
  final double triangleRadius = ringInnerRadius - AppLayout.colorWheelTriangleInset;
  final double colorAngle = _normalizeDegrees(hue);
  final Offset colorVertex = _offsetOnCircle(center, triangleRadius, colorAngle);
  final Offset whiteVertex = _offsetOnCircle(center, triangleRadius, colorAngle + AppMath.degrees120);
  final Offset blackVertex = _offsetOnCircle(center, triangleRadius, colorAngle - AppMath.degrees120);

  return (
    blackVertex: blackVertex,
    center: center,
    colorVertex: colorVertex,
    outerRadius: outerRadius,
    ringInnerRadius: ringInnerRadius,
    whiteVertex: whiteVertex,
  );
}

double _degreesToRadians(final double degrees) {
  return (degrees * AppMath.pi) / AppMath.degreesPerHalfTurn;
}

double _normalizeDegrees(final double degrees) {
  return (degrees % AppMath.degreesPerFullTurn + AppMath.degreesPerFullTurn) % AppMath.degreesPerFullTurn;
}

Offset _offsetOnCircle(
  final Offset center,
  final double radius,
  final double angleDegrees,
) {
  final double radians = _degreesToRadians(angleDegrees);
  return Offset(
    center.dx + math.cos(radians) * radius,
    center.dy + math.sin(radians) * radius,
  );
}

double _radiansToDegrees(final double radians) {
  return (radians * AppMath.degreesPerHalfTurn) / AppMath.pi;
}

({double black, double color, double white}) _triangleWeightsForHsv({
  required final double saturation,
  required final double value,
}) {
  final double clampedValue = value.clamp(0.0, AppVisual.full);
  final double clampedSaturation = saturation.clamp(0.0, AppVisual.full);
  final double color = clampedValue * clampedSaturation;
  final double white = clampedValue * (AppVisual.full - clampedSaturation);
  final double black = AppVisual.full - clampedValue;

  return (black: black, color: color, white: white);
}

Offset _trianglePointForWeights({
  required final Offset blackVertex,
  required final Offset colorVertex,
  required final ({double black, double color, double white}) weights,
  required final Offset whiteVertex,
}) {
  return Offset(
    (blackVertex.dx * weights.black) + (whiteVertex.dx * weights.white) + (colorVertex.dx * weights.color),
    (blackVertex.dy * weights.black) + (whiteVertex.dy * weights.white) + (colorVertex.dy * weights.color),
  );
}

/// Finds the best in-triangle point that approximates [targetColor] for the
/// current hue triangle.
Offset _triangleBestPointForColor({
  required final Offset blackVertex,
  required final Offset colorVertex,
  required final Color hueColor,
  required final Color targetColor,
  required final Offset whiteVertex,
}) {
  final Path trianglePath = Path()
    ..moveTo(blackVertex.dx, blackVertex.dy)
    ..lineTo(whiteVertex.dx, whiteVertex.dy)
    ..lineTo(colorVertex.dx, colorVertex.dy)
    ..close();
  final Rect bounds = trianglePath.getBounds();
  Offset bestPoint = _trianglePointForWeights(
    blackVertex: blackVertex,
    colorVertex: colorVertex,
    weights: (black: AppVisual.half, color: AppVisual.low, white: AppVisual.low),
    whiteVertex: whiteVertex,
  );
  double bestDistance = double.infinity;

  for (final double step in <double>[AppSpacing.medium, AppStroke.regular, AppVisual.half]) {
    for (double y = bounds.top; y <= bounds.bottom; y += step) {
      for (double x = bounds.left; x <= bounds.right; x += step) {
        final Offset point = Offset(x, y);
        final ({double black, double color, double white})? weights = _triangleWeightsForPoint(
          point: point,
          whiteVertex: whiteVertex,
          blackVertex: blackVertex,
          colorVertex: colorVertex,
        );

        if (weights == null) {
          continue;
        }

        final Color pointColor = _triangleColorForWeights(
          hueColor: hueColor,
          weights: weights,
        );
        final double distance = _colorDistanceSquared(pointColor, targetColor);

        if (distance < bestDistance) {
          bestDistance = distance;
          bestPoint = point;
        }
      }
    }
  }

  return bestPoint;
}

Color _triangleColorForWeights({
  required final Color hueColor,
  required final ({double black, double color, double white}) weights,
}) {
  return Color.fromARGB(
    AppLimits.rgbChannelMax,
    _weightedTriangleChannel(weights: weights, hueChannel: hueColor.r),
    _weightedTriangleChannel(weights: weights, hueChannel: hueColor.g),
    _weightedTriangleChannel(weights: weights, hueChannel: hueColor.b),
  );
}

double _colorDistanceSquared(final Color left, final Color right) {
  final double redDelta = left.r - right.r;
  final double greenDelta = left.g - right.g;
  final double blueDelta = left.b - right.b;
  return (redDelta * redDelta) + (greenDelta * greenDelta) + (blueDelta * blueDelta);
}

int _weightedTriangleChannel({
  required final ({double black, double color, double white}) weights,
  required final double hueChannel,
}) {
  final double weightedHueChannel = hueChannel * AppLimits.rgbChannelMax;
  final double weightedValue = (weights.white * AppLimits.rgbChannelMax) + (weights.color * weightedHueChannel);
  return weightedValue.round().clamp(AppMath.zero, AppLimits.rgbChannelMax);
}

/// Returns barycentric triangle weights for [point], or null when the point is
/// outside the SV triangle or the triangle is degenerate.
({double black, double color, double white})? _triangleWeightsForPoint({
  required final Offset point,
  required final Offset whiteVertex,
  required final Offset blackVertex,
  required final Offset colorVertex,
}) {
  final Offset whiteToBlack = blackVertex - whiteVertex;
  final Offset whiteToColor = colorVertex - whiteVertex;
  final Offset whiteToPoint = point - whiteVertex;
  final double dotBlackBlack = whiteToBlack.dx * whiteToBlack.dx + whiteToBlack.dy * whiteToBlack.dy;
  final double dotBlackColor = whiteToBlack.dx * whiteToColor.dx + whiteToBlack.dy * whiteToColor.dy;
  final double dotColorColor = whiteToColor.dx * whiteToColor.dx + whiteToColor.dy * whiteToColor.dy;
  final double dotPointBlack = whiteToPoint.dx * whiteToBlack.dx + whiteToPoint.dy * whiteToBlack.dy;
  final double dotPointColor = whiteToPoint.dx * whiteToColor.dx + whiteToPoint.dy * whiteToColor.dy;
  final double denominator = (dotBlackBlack * dotColorColor) - (dotBlackColor * dotBlackColor);

  if (denominator == 0) {
    return null;
  }

  final double normalizedBlack = ((dotColorColor * dotPointBlack) - (dotBlackColor * dotPointColor)) / denominator;
  final double normalizedColor = ((dotBlackBlack * dotPointColor) - (dotBlackColor * dotPointBlack)) / denominator;
  final double normalizedWhite = AppVisual.full - normalizedBlack - normalizedColor;
  const double tolerance = 0.001;

  if (normalizedWhite < -tolerance || normalizedBlack < -tolerance || normalizedColor < -tolerance) {
    return null;
  }

  return (
    black: normalizedBlack.clamp(0.0, AppVisual.full),
    color: normalizedColor.clamp(0.0, AppVisual.full),
    white: normalizedWhite.clamp(0.0, AppVisual.full),
  );
}
