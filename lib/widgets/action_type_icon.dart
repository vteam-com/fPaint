import 'package:flutter/material.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/widgets/svg_icon.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Returns an icon widget for the given action type.
Widget iconFromaActionType(
  final ActionType type,
  final bool isSelected,
) {
  switch (type) {
    case ActionType.pencil:
      return iconAndColor(Icons.create, isSelected);
    case ActionType.brush:
      return iconAndColor(Icons.brush, isSelected);
    case ActionType.line:
      return iconAndColor(Icons.line_axis, isSelected);
    case ActionType.circle:
      return iconAndColor(Icons.circle_outlined, isSelected);
    case ActionType.rectangle:
      return iconAndColor(Icons.crop_square, isSelected);
    case ActionType.region:
      return iconAndColor(Icons.crop, isSelected);
    case ActionType.fill:
      return iconAndColor(Icons.format_color_fill, isSelected);
    case ActionType.eraser:
      return iconFromSvgAsset(
        'assets/icons/eraser.svg',
        isSelected ? Colors.blue : Colors.white,
      );
    case ActionType.image:
      return iconAndColor(Icons.image, isSelected);
    case ActionType.cut:
      return iconAndColor(Icons.crop_free, isSelected);
    case ActionType.selector:
      return iconAndColor(Symbols.select, isSelected);
    case ActionType.text:
      return iconAndColor(Icons.font_download, isSelected);
  }
}

/// Returns an icon widget with the given icon data and color.
Icon iconAndColor(final IconData tool, [final bool isSelected = false]) {
  final Color? color = isSelected ? Colors.blue : null;
  return Icon(tool, color: color);
}
