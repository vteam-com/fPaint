import 'package:flutter/material.dart';

class TruncatedTextWidget extends StatelessWidget {
  const TruncatedTextWidget(
      {super.key, required this.text, this.maxLength = 6});
  final String text;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    String truncatedText = _truncateText(text);

    return SizedBox(
      width: double.infinity, // Ensure the text has a bounded width
      child: Text(
        truncatedText,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _truncateText(String text) {
    if (text.length <= maxLength) {
      return text; // No truncation needed for short texts
    }

    int splitLength = (maxLength / 2).floor();

    // Ensure the first character, middle ellipsis, and last character are kept
    String start = text.substring(0, splitLength);
    String end = text.substring(text.length - splitLength);

    // If there are multiple digits at the end, we keep them
    String middle = text.length > 3 ? '…' : '';

    return '$start$middle$end';
  }
}
