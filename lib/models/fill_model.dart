import 'package:flutter/material.dart';

// Exports
export 'package:fpaint/helpers/draw_path_helper.dart';

enum FillMode { solid, linear, radial }

class FillModel {
  bool isVisible = false;

  ///-------------------------------------------
  /// Mode
  FillMode _mode = FillMode.solid;
  FillMode get mode => _mode;
  set mode(final FillMode newMode) {
    _mode = newMode;
    if (_mode == FillMode.solid) {
      clear();
    }
  }

  List<GradientPoint> gradientPoints = <GradientPoint>[];

  void clear() {
    this.gradientPoints.clear();
    this.isVisible = false;
  }

  void addPoint(final GradientPoint pointToAdd) {
    this.gradientPoints.add(pointToAdd);
  }

  Offset get centerPoint => Offset(
        gradientPoints.fold<double>(
              0.0,
              (final double sum, final GradientPoint point) =>
                  sum + point.offset.dx,
            ) /
            gradientPoints.length,
        gradientPoints.fold<double>(
              0.0,
              (final double sum, final GradientPoint point) =>
                  sum + point.offset.dy,
            ) /
            gradientPoints.length,
      );
}

class GradientPoint {
  GradientPoint({
    required this.offset,
    required this.color,
  });
  Offset offset;
  Color color;
}
