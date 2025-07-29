import 'package:flutter/material.dart';

class TextObject {
  TextObject({
    required this.text,
    required this.position,
    required this.color,
    required this.size,
    this.fontWeight = FontWeight.normal,
    this.fontStyle = FontStyle.normal,
  });

  String text;
  Offset position;
  Color color;
  double size;
  FontWeight fontWeight;
  FontStyle fontStyle;

  /// Calculates the accurate bounds of this text object using TextPainter
  Rect getBounds() {
    if (text.isEmpty) {
      return Rect.fromLTWH(position.dx, position.dy, 0, 0);
    }

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    return Rect.fromLTWH(
      position.dx,
      position.dy,
      textPainter.width,
      textPainter.height,
    );
  }

  /// Checks if a point is within the text bounds
  bool containsPoint(final Offset point) {
    return getBounds().contains(point);
  }

  /// Gets the center point of the text
  Offset get center {
    final Rect bounds = getBounds();
    return Offset(
      bounds.left + bounds.width / 2,
      bounds.top + bounds.height / 2,
    );
  }
}
