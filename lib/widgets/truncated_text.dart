import 'package:flutter/material.dart';

/// A widget that displays a truncated version of a given text.
///
/// The text is truncated to a maximum length specified by [maxLength].
/// If the text is shorter than or equal to [maxLength], it is displayed as is.
/// If the text is longer than [maxLength], it is truncated to show the first and last few characters,
/// with an ellipsis in the middle.
class TruncatedTextWidget extends StatelessWidget {
  /// Creates a [TruncatedTextWidget].
  ///
  /// The [text] parameter specifies the text to display.
  /// The [maxLength] parameter specifies the maximum length of the truncated text.
  const TruncatedTextWidget({
    super.key,
    required this.text,
    this.maxLength = 6,
  });

  /// The maximum length of the truncated text.
  final int maxLength;

  /// The text to display.
  final String text;

  @override
  Widget build(final BuildContext context) {
    final String truncatedText = _truncateText(text);

    return SizedBox(
      width: double.infinity, // Ensure the text has a bounded width
      child: Text(
        truncatedText,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Truncates the given text to a maximum length.
  ///
  /// If the text is shorter than or equal to [maxLength], it is returned as is.
  /// If the text is longer than [maxLength], it is truncated to show the first and last few characters,
  /// with an ellipsis in the middle.
  String _truncateText(final String text) {
    if (text.length <= maxLength) {
      return text; // No truncation needed for short texts
    }

    final int splitLength = (maxLength / 2).floor();

    // Ensure the first character, middle ellipsis, and last character are kept
    final String start = text.substring(0, splitLength);
    final String end = text.substring(text.length - splitLength);

    // If there are multiple digits at the end, we keep them
    final String middle = text.length > 3 ? '…' : '';

    return '$start$middle$end';
  }
}
