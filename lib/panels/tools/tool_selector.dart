import 'package:flutter/material.dart';

class ToolSelector extends StatelessWidget {
  const ToolSelector({
    super.key,
    required this.name,
    required this.image,
    required this.isSelected,
    required this.onPressed,
  });

  final String name;
  final Widget image;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: image,
        onPressed: onPressed,
        tooltip: name,
      ),
    );
  }
}
