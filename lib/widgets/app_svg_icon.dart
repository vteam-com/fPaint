import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/app_icon.dart';

/// Standardized SVG icon widget for the app.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
  });
  final Color? color;
  final AppIcon icon;
  final double? size;
  @override
  Widget build(final BuildContext context) {
    final double resolvedSize = size ?? AppLayout.iconSize;
    final Color resolvedColor = color ?? IconTheme.of(context).color ?? Colors.white;
    final Key resolvedKey = key ?? ValueKey<String>('$appIconKeyPrefix${icon.name}');

    return SvgPicture.asset(
      icon.assetPath,
      key: resolvedKey,
      width: resolvedSize,
      height: resolvedSize,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcATop),
    );
  }
}
