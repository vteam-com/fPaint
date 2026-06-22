import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Builds a standard icon action button for shell and selection toolbars.
Widget buildToolbarIconButton({
  final Key? key,
  final String? tooltip,
  required final AppIcon icon,
  required final InteractionLayoutProfile interactionProfile,
  final bool enabled = true,
  final bool isSelected = false,
  final Color? color,
  final bool useSourceColors = false,
  required final VoidCallback onPressed,
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
