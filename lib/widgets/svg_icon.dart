import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

Widget iconFromSvgAssetSelected(
  final String assetsPathToImage,
  final bool isSelected,
) {
  return iconFromSvgAsset(
    assetsPathToImage,
    isSelected ? Colors.blue : Colors.white,
  );
}
