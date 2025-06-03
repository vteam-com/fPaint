import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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
  /// The [onColorPicked] parameter is a callback that is called when a color is picked.
  /// The [onClosed] parameter is a callback that is called when the eye dropper is closed.
  const MagnifyingEyeDropper({
    required this.layers,
    required this.pointerPosition,
    required this.pixelPosition,
    required this.onColorPicked,
    required this.onClosed,
    super.key,
  });

  /// The layers provider.
  final LayersProvider layers;

  /// The position of the pointer.
  final Offset pointerPosition;

  /// The position of the pixel to sample.
  final Offset pixelPosition;

  /// A callback that is called when a color is picked.
  final void Function(Color color) onColorPicked;

  /// A callback that is called when the eye dropper is closed.
  final void Function() onClosed;

  @override
  MagnifyingEyeDropperState createState() => MagnifyingEyeDropperState();
}

/// The state for [MagnifyingEyeDropper].
class MagnifyingEyeDropperState extends State<MagnifyingEyeDropper> {
  /// The selected color.
  Color? _selectedColor;

  /// The size of the button.
  final double buttonSize = 40;

  /// The size of the spacer.
  final double spacer = 4;

  /// The size of the region.
  final double regionSize = 100;

  /// The width of the widget.
  final double widgewidgetWidth = 50;

  /// The magnification factor.
  final double magnifyFactor = 6;

  /// The total height of the widget.
  late final double totalHeightOfTheWidget = buttonSize + spacer + regionSize + spacer + buttonSize;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(final BuildContext context) {
    if (widget.layers.cachedImage == null) {
      return const SizedBox();
    }

    _updateColor();

    final double offsetFromCenter = (widgewidgetWidth / 2) / magnifyFactor;

    final ui.Rect region = Rect.fromLTWH(
      widget.pixelPosition.dx - offsetFromCenter,
      widget.pixelPosition.dy - offsetFromCenter,
      offsetFromCenter,
      offsetFromCenter,
    );

    final ui.Image croppedImage = cropImage(widget.layers.cachedImage!, region);

    // Magnifying Glass Effect
    return Positioned(
      left: widget.pointerPosition.dx - (widgewidgetWidth),
      top: widget.pointerPosition.dy - (totalHeightOfTheWidget / 2),
      child: Column(
        spacing: spacer.toDouble(),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          //
          // Cancel 'X'
          //
          SizedBox(
            height: buttonSize.toDouble(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () {
                  widget.onClosed();
                },
                icon: const Icon(Icons.close),
              ),
            ),
          ),

          //
          // Show Color
          //
          SizedBox(
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
                      color: _selectedColor ?? Colors.black,
                    ),
                  ),
                ),
                DashedRectangle(
                  fillColor: _selectedColor ?? Colors.transparent,
                  width: 30,
                  height: 30,
                ),
              ],
            ),
          ),

          //
          // Confirmed CheckBox
          //
          SizedBox(
            height: buttonSize.toDouble(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () {
                  widget.onColorPicked(_selectedColor!);
                },
                icon: const Icon(Icons.check),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Updates the selected color.
  void _updateColor() async {
    if (widget.layers.cachedImage == null) {
      return;
    }

    final Color? color = await widget.layers.getColorAtOffset(widget.pixelPosition);

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
  void paint(final Canvas canvas, final Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant final CustomPainter oldDelegate) => false;
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
  void paint(final Canvas canvas, final Size size) {
    final double scaleFactor = 8.0;

    final Paint paint = Paint()
      ..shader = ImageShader(
        croppedImage,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().scaled(scaleFactor).storage,
      );

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      (size.width / 2) - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant final CustomPainter oldDelegate) => true;
}
