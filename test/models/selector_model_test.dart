import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/selector_model.dart';

void main() {
  group('SelectorModel', () {
    test('scaleUniform scales the selection path evenly around its center', () {
      final SelectorModel model = SelectorModel()..path1 = (Path()..addRect(const Rect.fromLTWH(0, 0, 100, 50)));

      model.scaleUniform(2);

      expect(model.boundingRect, const Rect.fromLTWH(-50, -25, 200, 100));
    });
  });
}
