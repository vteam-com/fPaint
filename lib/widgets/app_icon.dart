import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';

/// Standardized SVG icon widget for the app.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
    this.isSelected,
  });
  final Color? color;
  final AppIcon icon;

  /// When non-null, overrides [color] with blue (selected) or white (unselected).
  final bool? isSelected;
  final double? size;
  @override
  Widget build(final BuildContext context) {
    final double resolvedSize = size ?? AppLayout.iconSize;

    return SvgPicture.asset(
      icon.assetPath,
      key: key,
      width: resolvedSize,
      height: resolvedSize,
      colorFilter: ColorFilter.mode(defaultColor, BlendMode.srcIn),
    );
  }

  /// Calculates the default color based on the [color] property and selection state.
  Color get defaultColor {
    if (color == null) {
      if (isSelected == null || isSelected == false) {
        return AppColors.white;
      } else {
        return AppColors.selected;
      }
    }
    return color!;
  }
}
