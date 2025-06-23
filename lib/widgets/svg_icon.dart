import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    width: 24.0,
    height: 24.0,
    colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
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
