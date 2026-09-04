// ignore: fcheck_one_class_per_file
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/draw_rect.dart';

/// A widget that displays a magnifying eye dropper for selecting colors from an image.
class MagnifyingEyeDropper extends StatefulWidget {
  /// Creates a [MagnifyingEyeDropper].
  ///
  /// The [layers] parameter specifies the layers provider.
  /// The [pointerPosition] parameter specifies the position of the pointer.
  /// The [pixelPosition] parameter specifies the position of the pixel to sample.
  const MagnifyingEyeDropper({
    required this.layers,
    required this.pointerPosition,
    required this.pixelPosition,
    super.key,
  });

  /// The layers provider.
  final LayersProvider layers;

  /// The position of the pixel to sample.
  final Offset pixelPosition;

  /// The position of the pointer.
  final Offset pointerPosition;

  @override
  MagnifyingEyeDropperState createState() => MagnifyingEyeDropperState();
}

/// The state for [MagnifyingEyeDropper].
class MagnifyingEyeDropperState extends State<MagnifyingEyeDropper> {
  /// Monotonic id used to ignore stale async color-sampling results.
  int _colorSampleRequestId = 0;

  /// The selected color.
  Color? _selectedColor;

  /// The size of the region.
  final double regionSize = AppLayout.previewRegionSize;

  @override
  void initState() {
    super.initState();
    _updateColor();
  }

  @override
  void didUpdateWidget(covariant MagnifyingEyeDropper oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pixelPosition != widget.pixelPosition || oldWidget.layers.cachedImage != widget.layers.cachedImage) {
      _updateColor();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.layers.cachedImage == null) {
      return const SizedBox();
    }

    const int gridCount = AppInteraction.magnifierGridCount;
    const int halfGrid = (gridCount - 1) ~/ 2;

    final int centerPixelX = widget.pixelPosition.dx.floor();
    final int centerPixelY = widget.pixelPosition.dy.floor();

    final ui.Rect region = Rect.fromLTWH(
      (centerPixelX - halfGrid).toDouble(),
      (centerPixelY - halfGrid).toDouble(),
      gridCount.toDouble(),
      gridCount.toDouble(),
    );

    final ui.Image croppedImage = cropImage(widget.layers.cachedImage!, region);

    // Magnifying Glass Effect
    return Positioned(
      left: widget.pointerPosition.dx - (regionSize / AppMath.pair),
      top: widget.pointerPosition.dy - (regionSize / AppMath.pair),
      child: IgnorePointer(
        child: SizedBox(
          width: regionSize,
          height: regionSize,
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: <Widget>[
              SizedBox(
                width: regionSize,
                height: regionSize,
                child: CustomPaint(
                  painter: MagnifyingGlassPainter(
                    croppedImage: croppedImage,
                    color: _selectedColor ?? AppColors.black,
                  ),
                ),
              ),
              DashedRectangle(
                fillColor: _selectedColor ?? AppColors.transparent,
                width: AppLayout.magnifierTargetSize,
                height: AppLayout.magnifierTargetSize,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Updates the selected color.
  void _updateColor() async {
    if (widget.layers.cachedImage == null) {
      if (mounted && _selectedColor != null) {
        setState(() {
          _selectedColor = null;
        });
      }
      return;
    }

    final int requestId = ++_colorSampleRequestId;

    final Color? color = await widget.layers.getColorAtOffset(
      widget.pixelPosition,
      useCachedImage: true,
    );

    if (!mounted || requestId != _colorSampleRequestId || color == _selectedColor) {
      return;
    }

    setState(() {
      _selectedColor = color;
    });
  }
}

/// Paints the image.
class ImagePainter extends CustomPainter {
  /// Creates an [ImagePainter].
  ImagePainter(this.image);

  /// The image to paint.
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
