import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Builds a standard icon action button for shell and selection toolbars.
Widget buildToolbarIconButton({
  Key? key,
  String? tooltip,
  required AppIcon icon,
  required InteractionLayoutProfile interactionProfile,
  bool enabled = true,
  bool isSelected = false,
  Color? color,
  bool useSourceColors = false,
  required VoidCallback onPressed,
}) {
  return AppButtonIcon(
    key: key,
    tooltip: tooltip,
    icon: icon,
    isSelected: isSelected,
    color: color,
    size: interactionProfile.iconSize,
    enabled: enabled,
    useSourceColors: useSourceColors,
    onPressed: onPressed,
  );
}
