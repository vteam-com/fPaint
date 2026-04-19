import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/svg_icon.dart';

/// Returns an icon widget for the given action type.
Widget iconFormatActionType(
  final ActionType type,
  final bool isSelected,
) {
  switch (type) {
    case ActionType.pencil:
      return iconFromAppIconSelected(AppIcon.create, isSelected);
    case ActionType.brush:
      return iconFromAppIconSelected(AppIcon.brush, isSelected);
    case ActionType.line:
      return iconFromAppIconSelected(AppIcon.lineAxis, isSelected);
    case ActionType.circle:
      return iconFromAppIconSelected(AppIcon.circle, isSelected);
    case ActionType.rectangle:
      return iconFromAppIconSelected(AppIcon.cropSquare, isSelected);
    case ActionType.region:
      return iconFromAppIconSelected(AppIcon.canvasCrop, isSelected);
    case ActionType.fill:
      return iconFromAppIconSelected(AppIcon.formatColorFill, isSelected);
    case ActionType.eraser:
      return iconFromSvgAsset(
        AppToolIconAssets.eraser,
        isSelected ? Colors.blue : Colors.white,
      );
    case ActionType.image:
      return iconFromAppIconSelected(AppIcon.image, isSelected);
    case ActionType.cut:
      return iconFromAppIconSelected(AppIcon.cropFree, isSelected);
    case ActionType.selector:
      return iconFromSvgAsset(
        AppToolIconAssets.selectorReplace,
        isSelected ? Colors.blue : Colors.white,
      );
    case ActionType.text:
      return iconFromAppIconSelected(AppIcon.fontDownload, isSelected);
  }
}
