import 'package:flutter/material.dart';

class ToolItem extends StatelessWidget {
  const ToolItem({
    super.key,
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: name,
      ),
    );
  }
}
