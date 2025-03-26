import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/draw_rect.dart';

class MagnifyingEyeDropper extends StatefulWidget {
  const MagnifyingEyeDropper({
    required this.layers,
    required this.pointerPosition,
    required this.pixelPosition,
    required this.onColorPicked,
    required this.onClosed,
    super.key,
  });
  final LayersProvider layers;
  final Offset pointerPosition;
  final Offset pixelPosition;
  final void Function(Color color) onColorPicked;
  final void Function() onClosed;

  @override
  MagnifyingEyeDropperState createState() => MagnifyingEyeDropperState();
}

class MagnifyingEyeDropperState extends State<MagnifyingEyeDropper> {
  Color? _selectedColor;

  final double buttonSize = 40;
  final double spacer = 4;
  final double regionSize = 100;
  final double widgewidgetWidth = 50;
  final double magnifyFactor = 6;
  late final double totalHeightOfTheWidget =
      buttonSize + spacer + regionSize + spacer + buttonSize;

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

  void _updateColor() async {
    if (widget.layers.cachedImage == null) {
      return;
    }

    final Color? color =
        await widget.layers.getColorAtOffset(widget.pixelPosition);

    setState(() {
      _selectedColor = color;
    });
  }
}

// 🖼 Paint the Image
class ImagePainter extends CustomPainter {
  ImagePainter(this.image);
  final ui.Image image;

  @override
  void paint(final Canvas canvas, final Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant final CustomPainter oldDelegate) => false;
}

// 🔍 Draw the Magnifying Glass
class MagnifyingGlassPainter extends CustomPainter {
  MagnifyingGlassPainter({
    required this.croppedImage,
    required this.color,
  });

  final ui.Image croppedImage;
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
