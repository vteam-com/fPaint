import 'package:flutter/material.dart';

/// Represents a selectable tool in the user interface.
///
/// The [ToolSelector] widget displays an icon button with a border that indicates
/// whether the tool is currently selected. When the button is pressed, the
/// [onPressed] callback is invoked.
///
/// The [name] parameter provides a tooltip for the button, and the [image]
/// parameter specifies the icon to be displayed.

class ToolSelector extends StatelessWidget {
  const ToolSelector({
    super.key,
    required this.name,
    required this.image,
    required this.isSelected,
    required this.minimal,
    required this.onPressed,
  });

  final String name;
  final Widget image;
  final bool isSelected;
  final bool minimal;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: minimal ? const EdgeInsets.all(2) : const EdgeInsets.all(8),
        child: IconButton(
          icon: image,
          onPressed: onPressed,
          tooltip: name,
          constraints: minimal ? const BoxConstraints() : null,
          padding: minimal ? EdgeInsets.zero : const EdgeInsets.all(8),
        ),
      ),
    );
  }
}
