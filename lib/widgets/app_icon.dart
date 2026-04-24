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
    final Color resolvedColor = isSelected != null
        ? (isSelected! ? AppPalette.blue : AppPalette.white)
        : color ?? AppPalette.white;

    return SvgPicture.asset(
      icon.assetPath,
      key: key,
      width: resolvedSize,
      height: resolvedSize,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcATop),
    );
  }
}
