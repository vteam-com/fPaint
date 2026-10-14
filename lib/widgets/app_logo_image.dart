import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// The fPaint app logo, drawn as a square of side [size].
class AppLogoImage extends StatelessWidget {
  /// Creates an [AppLogoImage].
  const AppLogoImage({super.key, required this.size});

  /// Width and height of the logo.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      appLogoAssetPath,
      width: size,
      height: size,
      package: appAssetsPackage,
    );
  }
}
