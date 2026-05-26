// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/visible_model.dart';

// Exports
export 'package:fpaint/helpers/draw_path_helper.dart';

/// Defines the available fill modes for shapes in the paint application.
///
/// - [solid]: Single color fill
/// - [linear]: Linear gradient fill with two or more color stops
/// - [radial]: Radial gradient fill emanating from a center point
enum FillMode { solid, linear, radial }

/// Manages fill properties and gradient configuration for shapes.
///
/// This model extends [VisibleModel] to provide visibility control and manages
/// different fill modes including solid colors and gradients. It handles the
/// creation and manipulation of gradient points for linear and radial fills.
///
/// The model supports:
/// - Solid color fills
/// - Linear gradients with multiple color stops
/// - Radial gradients with configurable center points
/// - Dynamic gradient point management
class FillModel extends VisibleModel {
  ///-------------------------------------------
  /// Mode
  FillMode _mode = FillMode.solid;

  /// Whether flood fill should render as a halftone pattern.
  bool halftoneEnabled = false;

  int _halftoneMaxDotSizePercent = AppHalftone.defaultDotSizePercent;

  /// Relative maximum dot size for halftone flood fill in percent.
  int get halftoneMaxDotSizePercent => _halftoneMaxDotSizePercent;

  /// Relative maximum dot size for halftone flood fill in percent.
  set halftoneMaxDotSizePercent(final int value) {
    _halftoneMaxDotSizePercent = value.clamp(AppMath.zero, AppLimits.percentMax);
  }

  /// Relative maximum dot radius scale for halftone rendering.
  double get halftoneMaxDotSizeFactor => _halftoneMaxDotSizePercent / AppLimits.percentMax;

  /// Gets the current fill mode.
  FillMode get mode => _mode;

  /// Sets the fill mode.
  set mode(final FillMode newMode) {
    _mode = newMode;
    if (_mode == FillMode.solid) {
      clear();
    }
  }

  List<GradientPoint> gradientPoints = <GradientPoint>[];

  /// The ordered list of color stops for the gradient (minimum 2).
  ///
  /// This is the authoritative color list used for rendering and the side-panel
  /// editor.  The first entry corresponds to the start handle color and the
  /// last entry corresponds to the end/outer handle color.  Intermediate entries
  /// produce additional color stops that are distributed evenly between the two
  /// handles.
  List<Color> gradientStopColors = <Color>[
    AppColors.gradientDefaultStart,
    AppColors.gradientDefaultEnd,
  ];

  /// The ordered list of stop positions for the gradient (values 0.0–1.0).
  ///
  /// Must have the same length as [gradientStopColors].  The first value is
  /// always `0.0` and the last is always `1.0`.  Inner values must be strictly
  /// between the surrounding values so the gradient always renders correctly.
  List<double> gradientStopPositions = <double>[0.0, 1.0];

  /// Minimum number of color stops for a gradient.
  static const int gradientStopMin = 2;

  /// Clears the gradient points and hides the fill.
  @override
  void clear() {
    this.gradientPoints.clear();
    this.isVisible = false;
  }

  /// Adds a gradient point to the list of gradient points.
  void addPoint(final GradientPoint pointToAdd) {
    this.gradientPoints.add(pointToAdd);
  }

  /// Calculates the center point of the gradient based on the gradient points.
  Offset get centerPoint => Offset(
    gradientPoints.fold<double>(
          0.0,
          (final double sum, final GradientPoint point) => sum + point.offset.dx,
        ) /
        gradientPoints.length,
    gradientPoints.fold<double>(
          0.0,
          (final double sum, final GradientPoint point) => sum + point.offset.dy,
        ) /
        gradientPoints.length,
  );
}

/// Represents a point in a gradient with an offset and a color.
class GradientPoint {
  GradientPoint({
    required this.offset,
    required this.color,
  });

  /// The offset of the gradient point.
  Offset offset;

  /// The color of the gradient point.
  Color color;
}
