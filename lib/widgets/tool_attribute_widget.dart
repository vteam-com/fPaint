import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';

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
        width: AppLayout.toolbarButtonSize,
        height: AppLayout.toolbarButtonSize,
        child: childLeft!,
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: minimal ? 0 : AppSpacing.sm),
      child: Tooltip(
        message: name,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: AppSpacing.md,
          children: <Widget>[
            // ignore: use_null_aware_elements
            if (childLeft != null) childLeft!,
            if (childRight case final Widget childRightWidget?)
              Expanded(
                child: childRightWidget,
              ),
          ],
        ),
      ),
    );
  }
}
