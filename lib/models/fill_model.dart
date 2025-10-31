import 'package:flutter/material.dart';
import 'package:fpaint/models/visible_model.dart';

// Exports
export 'package:fpaint/helpers/draw_path_helper.dart';

/// Represents the different fill modes available.
enum FillMode { solid, linear, radial }

/// Represents the fill properties for a shape.
class FillModel extends VisibleModel {
  ///-------------------------------------------
  /// Mode
  FillMode _mode = FillMode.solid;

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
