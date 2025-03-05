import 'package:flutter/material.dart';

// Exports
export 'package:fpaint/helpers/draw_path_helper.dart';

enum FillMode { solid, linear, radial }

class FillModel {
  bool isVisible = false;
  FillMode mode = FillMode.solid;

  List<GradientPoint> gradientPoints = <GradientPoint>[];

  void clear() {
    this.isVisible = false;
    this.gradientPoints.clear();
  }

  void addPoint(final GradientPoint pointToAdd) {
    isVisible = true;
    this.gradientPoints.add(pointToAdd);
  }
}

class GradientPoint {
  GradientPoint({
    required this.offset,
    required this.color,
  });
  Offset offset;
  Color color;
}
