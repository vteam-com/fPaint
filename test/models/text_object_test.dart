import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/text_object.dart';

void main() {
  group('TextObject', () {
    test('constructor sets all properties correctly', () {
      final TextObject textObject = TextObject(
        text: 'Hello',
        position: const Offset(10, 20),
        color: Colors.red,
        size: 16.0,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      );

      expect(textObject.text, 'Hello');
      expect(textObject.position, const Offset(10, 20));
      expect(textObject.color, Colors.red);
      expect(textObject.size, 16.0);
      expect(textObject.fontWeight, FontWeight.bold);
      expect(textObject.fontStyle, FontStyle.italic);
    });

    test('constructor uses default values for optional parameters', () {
      final TextObject textObject = TextObject(
        text: 'Test',
        position: const Offset(5, 10),
        color: Colors.blue,
        size: 12.0,
      );

      expect(textObject.fontWeight, FontWeight.normal);
      expect(textObject.fontStyle, FontStyle.normal);
    });

    test('getBounds returns correct bounds for non-empty text', () {
      final TextObject textObject = TextObject(
        text: 'Test',
        position: const Offset(10, 20),
        color: Colors.black,
        size: 16.0,
      );

      final Rect bounds = textObject.getBounds();

      expect(bounds.left, 10.0);
      expect(bounds.top, 20.0);
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('getBounds returns zero-sized rect for empty text', () {
      final TextObject textObject = TextObject(
        text: '',
        position: const Offset(10, 20),
        color: Colors.black,
        size: 16.0,
      );

      final Rect bounds = textObject.getBounds();

      expect(bounds.left, 10.0);
      expect(bounds.top, 20.0);
      expect(bounds.width, 0.0);
      expect(bounds.height, 0.0);
    });

    test('containsPoint returns true for point inside bounds', () {
      final TextObject textObject = TextObject(
        text: 'Test',
        position: const Offset(10, 20),
        color: Colors.black,
        size: 16.0,
      );

      final Rect bounds = textObject.getBounds();
      final Offset centerPoint = Offset(
        bounds.left + bounds.width / 2,
        bounds.top + bounds.height / 2,
      );

      expect(textObject.containsPoint(centerPoint), true);
    });

    test('containsPoint returns false for point outside bounds', () {
      final TextObject textObject = TextObject(
        text: 'Test',
        position: const Offset(10, 20),
        color: Colors.black,
        size: 16.0,
      );

      expect(textObject.containsPoint(const Offset(0, 0)), false);
      expect(textObject.containsPoint(const Offset(1000, 1000)), false);
    });

    test('center returns correct center point', () {
      final TextObject textObject = TextObject(
        text: 'Test',
        position: const Offset(10, 20),
        color: Colors.black,
        size: 16.0,
      );

      final Rect bounds = textObject.getBounds();
      final Offset expectedCenter = Offset(
        bounds.left + bounds.width / 2,
        bounds.top + bounds.height / 2,
      );

      expect(textObject.center, expectedCenter);
    });

    test('center works for empty text', () {
      final TextObject textObject = TextObject(
        text: '',
        position: const Offset(10, 20),
        color: Colors.black,
        size: 16.0,
      );

      expect(textObject.center, const Offset(10, 20));
    });

    test('bounds calculation considers font properties', () {
      final TextObject normalText = TextObject(
        text: 'Test',
        position: const Offset(0, 0),
        color: Colors.black,
        size: 16.0,
        fontWeight: FontWeight.normal,
      );

      final TextObject boldText = TextObject(
        text: 'Test',
        position: const Offset(0, 0),
        color: Colors.black,
        size: 16.0,
        fontWeight: FontWeight.bold,
      );

      // Bold text might have different bounds than normal text
      final Rect normalBounds = normalText.getBounds();
      final Rect boldBounds = boldText.getBounds();

      // At minimum, they should have the same position
      expect(normalBounds.left, boldBounds.left);
      expect(normalBounds.top, boldBounds.top);
    });
  });
}
