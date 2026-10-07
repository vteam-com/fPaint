// ignore: fcheck_one_class_per_file
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/widgets/draw_rect.dart';

/// The circular on-canvas loupe shared by the pick-from-canvas gestures.
///
/// It magnifies [magnifiedRegion] — the pixel grid around the sampled pixel —
/// and marks the sampled
/// pixel, so the value about to be picked is visible before the gesture
/// commits and is never hidden under the finger. The eyedropper and the layer
/// picker differ only in what they do with the sample and in the optional
/// [caption] shown beneath the loupe.
class MagnifierLoupe extends StatelessWidget {
  /// Creates a [MagnifierLoupe].
  const MagnifierLoupe({
    required this.magnifiedRegion,
    required this.pointerPosition,
    required this.sampledColor,
    this.caption,
    super.key,
  });

  /// Optional label rendered directly beneath the loupe.
  final Widget? caption;

  /// The composited pixels around the sampled pixel, i.e. [regionAround] of
  /// it. The caller renders and owns it; the loupe only draws it. Null until
  /// the first sample lands: the loupe shows immediately on arm and fills in,
  /// rather than appearing only once the sample completes.
  final ui.Image? magnifiedRegion;

  /// The screen position the loupe centers on.
  final Offset pointerPosition;

  /// The color sampled under the crosshair, used to tint it.
  final Color? sampledColor;
  @override
  Widget build(BuildContext context) {
    const double regionSize = AppLayout.previewRegionSize;
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
                    croppedImage: magnifiedRegion,
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

  /// The canvas rect the loupe magnifies around [pixelPosition]: a
  /// [AppInteraction.magnifierGridCount]-pixel square centered on it.
  static ui.Rect regionAround(Offset pixelPosition) {
    const int gridCount = AppInteraction.magnifierGridCount;
    const int halfGrid = (gridCount - 1) ~/ 2;
    return Rect.fromLTWH(
      (pixelPosition.dx.floor() - halfGrid).toDouble(),
      (pixelPosition.dy.floor() - halfGrid).toDouble(),
      gridCount.toDouble(),
      gridCount.toDouble(),
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

  /// The magnified pixels, or null while the first sample is in flight.
  final ui.Image? croppedImage;

  /// The color.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final Rect circleRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.clipPath(Path()..addOval(circleRect));

    canvas.drawRect(circleRect, Paint()..color = AppColors.grey300);

    final ui.Image? image = croppedImage;
    if (image != null) {
      final Rect srcRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      canvas.drawImageRect(
        image,
        srcRect,
        circleRect,
        Paint()..filterQuality = ui.FilterQuality.none,
      );
    }
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
