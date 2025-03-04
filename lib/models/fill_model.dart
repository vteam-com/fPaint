import 'package:flutter/material.dart';

// Exports
export 'package:fpaint/helpers/draw_path_helper.dart';

enum FillMode { solid, linear, radial }

class FillModel {
  bool isVisible = false;
  FillMode mode = FillMode.solid;

  List<Offset> points = <Offset>[];

  void clear() {
    this.isVisible = false;
    this.points.clear();
  }

  void translate(final Offset offset) {
    final Matrix4 matrix = Matrix4.identity()..translate(offset.dx, offset.dy);
    for (int i = 0; i < points.length; i++) {
      points[i] = MatrixUtils.transformPoint(matrix, points[i]);
    }
  }

  void addPoint(final Offset pointToAdd) {
    isVisible = true;
    this.points.add(pointToAdd);
  }
}
