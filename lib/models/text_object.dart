import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// Represents a text element placed on the canvas with style and position.
class TextObject {
  TextObject({
    required this.text,
    required this.position,
    required this.color,
    required this.size,
    this.fontFamily,
    this.fontWeight = FontWeight.normal,
    this.fontStyle = FontStyle.normal,
    this.textAlign = TextAlign.left,
  });

  String text;
  Offset position;
  Color color;
  double size;
  String? fontFamily;
  FontWeight fontWeight;
  FontStyle fontStyle;
  TextAlign textAlign;

  /// Builds a paragraph using the same style and layout settings as rendering.
  ui.Paragraph buildParagraph() {
    final ui.ParagraphBuilder paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: textAlign,
              fontFamily: fontFamily,
              fontSize: size,
              height: AppVisual.iconScale,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontFamily: fontFamily,
              fontWeight: fontWeight,
              fontStyle: fontStyle,
              fontSize: size,
            ),
          )
          ..addText(text);

    return paragraphBuilder.build();
  }

  /// Returns the maximum paragraph width used before text wraps.
  double get maxLayoutWidth {
    return text.length > AppLayout.textLengthThreshold ? AppLayout.textMaxWidthCompact : AppLayout.textMaxWidthNormal;
  }

  /// Builds and lays out a paragraph ready for measuring or painting.
  ui.Paragraph layoutParagraph() {
    final ui.Paragraph paragraph = buildParagraph();
    paragraph.layout(ui.ParagraphConstraints(width: maxLayoutWidth));
    return paragraph;
  }

  /// Calculates the accurate bounds of this text object using TextPainter
  Rect getBounds() {
    if (text.isEmpty) {
      return Rect.fromLTWH(position.dx, position.dy, 0, 0);
    }

    final ui.Paragraph paragraph = layoutParagraph();

    return Rect.fromLTWH(
      position.dx,
      position.dy,
      paragraph.maxIntrinsicWidth > maxLayoutWidth ? maxLayoutWidth : paragraph.maxIntrinsicWidth,
      paragraph.height,
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
      bounds.left + bounds.width / AppMath.pair,
      bounds.top + bounds.height / AppMath.pair,
    );
  }
}
