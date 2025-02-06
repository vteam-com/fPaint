import 'package:flutter/material.dart';

class ToolAttributeWidget extends StatelessWidget {
  const ToolAttributeWidget({
    super.key,
    required this.name,
    this.childLeft,
    this.childRight,
  });

  final String name;
  final Widget? childLeft;
  final Widget? childRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
