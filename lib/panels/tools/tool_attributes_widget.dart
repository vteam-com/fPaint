import 'package:flutter/material.dart';

/// A widget that displays a tool attribute with a label and a child widget.
class ToolAttributeWidget extends StatelessWidget {
  const ToolAttributeWidget({
    super.key,
    required this.name,
    required this.minimal,
    this.childLeft,
    this.childRight,
  });

  /// The widget to display on the left side of the tool attribute.
  final Widget? childLeft;

  /// The widget to display on the right side of the tool attribute.
  final Widget? childRight;

  /// Whether the widget is in minimal mode.
  final bool minimal;

  /// The name of the tool attribute.
  final String name;

  @override
  Widget build(final BuildContext context) {
    if (minimal && childRight == null) {
      return SizedBox(
        width: 50,
        height: 50,
        child: childLeft!,
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: minimal ? 0 : 8.0),
      child: Tooltip(
        message: name,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: <Widget>[
            if (childLeft != null) childLeft!,
            if (childRight != null)
              Expanded(
                child: childRight!,
              ),
          ],
        ),
      ),
    );
  }
}
