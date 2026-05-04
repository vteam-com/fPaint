import 'package:flutter/widgets.dart';
import 'package:fpaint/models/text_object.dart';

/// Persistent style settings for creating and editing text.
class TextToolState {
  TextToolState({
    required this.size,
    required this.color,
    this.fontWeight = FontWeight.normal,
    this.fontStyle = FontStyle.normal,
    this.textAlign = TextAlign.left,
  });

  factory TextToolState.fromTextObject(final TextObject textObject) {
    return TextToolState(
      size: textObject.size,
      color: textObject.color,
      fontWeight: textObject.fontWeight,
      fontStyle: textObject.fontStyle,
      textAlign: textObject.textAlign,
    );
  }

  double size;
  Color color;
  FontWeight fontWeight;
  FontStyle fontStyle;
  TextAlign textAlign;

  /// Creates an independent copy of this tool state.
  TextToolState copy() {
    return TextToolState(
      size: size,
      color: color,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textAlign: textAlign,
    );
  }

  /// Builds a [TextObject] using the current tool style at [position].
  TextObject buildTextObject({
    required final String text,
    required final Offset position,
    final String? fontFamily,
  }) {
    return TextObject(
      text: text,
      position: position,
      color: color,
      size: size,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textAlign: textAlign,
    );
  }
}
