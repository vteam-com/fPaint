// ignore: fcheck_one_class_per_file
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/widgets/draw_rect.dart';

/// The circular on-canvas loupe shared by the pick-from-canvas gestures.
///
/// It magnifies the pixel grid around [pixelPosition] and marks the sampled
/// pixel, so the value about to be picked is visible before the gesture
/// commits and is never hidden under the finger. The eyedropper and the layer
/// picker differ only in what they do with the sample and in the optional
/// [caption] shown beneath the loupe.
class MagnifierLoupe extends StatelessWidget {
  /// Creates a [MagnifierLoupe].
  const MagnifierLoupe({
    required this.sourceImage,
    required this.pointerPosition,
    required this.pixelPosition,
    required this.sampledColor,
    this.caption,
    super.key,
  });

  /// Optional label rendered directly beneath the loupe.
  final Widget? caption;

  /// The canvas pixel under the crosshair.
  final Offset pixelPosition;

  /// The screen position the loupe centers on.
  final Offset pointerPosition;

  /// The color sampled at [pixelPosition], used to tint the crosshair.
  final Color? sampledColor;

  /// The composited canvas image the loupe magnifies.
  final ui.Image sourceImage;

  @override
  Widget build(BuildContext context) {
    const int gridCount = AppInteraction.magnifierGridCount;
    const int halfGrid = (gridCount - 1) ~/ 2;
    const double regionSize = AppLayout.previewRegionSize;

    final int centerPixelX = pixelPosition.dx.floor();
    final int centerPixelY = pixelPosition.dy.floor();

    final ui.Rect region = Rect.fromLTWH(
      (centerPixelX - halfGrid).toDouble(),
      (centerPixelY - halfGrid).toDouble(),
      gridCount.toDouble(),
      gridCount.toDouble(),
    );

    final ui.Image croppedImage = cropImage(sourceImage, region);
    final Widget? captionWidget = caption;

    return Positioned(
      left: pointerPosition.dx - (regionSize / AppMath.pair),
      top: pointerPosition.dy - (regionSize / AppMath.pair),
      child: IgnorePointer(
        child: SizedBox(
          width: regionSize,
          height: regionSize,
          child: Stack(
            alignment: AlignmentDirectional.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              SizedBox(
                width: regionSize,
                height: regionSize,
                child: CustomPaint(
                  painter: MagnifyingGlassPainter(
                    croppedImage: croppedImage,
                    color: sampledColor ?? AppColors.black,
                  ),
                ),
              ),
              DashedRectangle(
                fillColor: sampledColor ?? AppColors.transparent,
                width: AppLayout.magnifierTargetSize,
                height: AppLayout.magnifierTargetSize,
              ),
              if (captionWidget != null) Positioned(top: regionSize, child: captionWidget),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the magnifying glass.
class MagnifyingGlassPainter extends CustomPainter {
  /// Creates a [MagnifyingGlassPainter].
  MagnifyingGlassPainter({
    required this.croppedImage,
    required this.color,
  });

  /// The cropped image.
  final ui.Image croppedImage;

  /// The color.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final Rect circleRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.clipPath(Path()..addOval(circleRect));

    canvas.drawRect(circleRect, Paint()..color = AppColors.grey300);

    final Rect srcRect = Rect.fromLTWH(
      0,
      0,
      croppedImage.width.toDouble(),
      croppedImage.height.toDouble(),
    );
    canvas.drawImageRect(
      croppedImage,
      srcRect,
      circleRect,
      Paint()..filterQuality = ui.FilterQuality.none,
    );
    canvas.restore();

    canvas.drawCircle(
      Offset(size.width / AppMath.pair, size.height / AppMath.pair),
      size.width / AppMath.pair,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.regular
        ..color = AppColors.black,
    );
    canvas.drawCircle(
      Offset(size.width / AppMath.pair, size.height / AppMath.pair),
      (size.width / AppMath.pair) - AppStroke.thin,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.regular
        ..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
