import 'package:flutter/material.dart';

/// Represents a selectable tool in the user interface.
///
/// The [ToolPanelPicker] widget displays an icon button with a border that indicates
/// whether the tool is currently selected. When the button is pressed, the
/// [onPressed] callback is invoked.
///
/// The [name] parameter provides a tooltip for the button, and the [image]
/// parameter specifies the icon to be displayed.
class ToolPanelPicker extends StatelessWidget {
  const ToolPanelPicker({
    super.key,
    required this.name,
    required this.image,
    required this.minimal,
    required this.onPressed,
  });

  /// The name of the tool, used for the tooltip.
  final String name;

  /// The widget to display as the tool's icon.
  final Widget image;

  /// A boolean indicating whether the tool panel is in minimal mode.
  final bool minimal;

  /// The callback function to be executed when the tool is pressed.
  final VoidCallback onPressed;

  @override
  Widget build(final BuildContext context) {
    return IconButton(
      icon: image,
      onPressed: onPressed,
      tooltip: name,
      constraints: minimal ? const BoxConstraints() : null,
      padding: EdgeInsets.all(minimal ? 2 : 8),
    );
  }
}
