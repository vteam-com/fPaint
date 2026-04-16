import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_svg_icon.dart';

/// Creates an [SvgPicture] widget from an SVG asset.
///
/// The [assetsPathToImage] parameter specifies the path to the SVG asset.
/// The [color] parameter specifies the color to apply to the SVG icon.
///
/// Returns an [SvgPicture] widget.
Widget iconFromSvgAsset(
  final String assetsPathToImage, [
  final Color color = Colors.white,
]) {
  return SvgPicture.asset(
    assetsPathToImage,
    width: AppLayout.iconSize,
    height: AppLayout.iconSize,
    colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
  );
}

/// Creates an app SVG icon from an [AppIcon].
Widget iconFromAppIcon(
  final AppIcon icon, [
  final Color color = Colors.white,
]) {
  return AppSvgIcon(icon: icon, color: color);
}

/// Creates an app SVG icon from an [AppIcon], tinted based on selection state.
Widget iconFromAppIconSelected(
  final AppIcon icon,
  final bool isSelected,
) {
  return iconFromAppIcon(
    icon,
    isSelected ? Colors.blue : Colors.white,
  );
}

/// Creates an [SvgPicture] widget from an SVG asset, with a color that depends on whether the icon is selected.
///
/// The [assetsPathToImage] parameter specifies the path to the SVG asset.
/// The [isSelected] parameter specifies whether the icon is selected.
///
/// Returns an [SvgPicture] widget with a color of blue if the icon is selected, or white if it is not.
Widget iconFromSvgAssetSelected(
  final String assetsPathToImage,
  final bool isSelected,
) {
  return iconFromSvgAsset(
    assetsPathToImage,
    isSelected ? Colors.blue : Colors.white,
  );
}
