import 'package:flutter/material.dart';

class ToolAttributeWidget extends StatelessWidget {
  const ToolAttributeWidget({
    super.key,
    required this.name,
    required this.minimal,
    this.childLeft,
    this.childRight,
  });

  final bool minimal;
  final String name;
  final Widget? childLeft;
  final Widget? childRight;

  @override
  Widget build(BuildContext context) {
    if (minimal && childRight == null) {
      return childLeft!;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: minimal ? 0 : 8.0),
      child: Tooltip(
        message: name,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
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
