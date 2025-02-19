import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ImagePainter extends CustomPainter {
  ImagePainter(this.image);
  final ui.Image image;

  @override
  void paint(final Canvas canvas, final Size size) {
    final ui.Paint paint = Paint();

    // Calculate the scale factors to fit the image into the destination rectangle
    final double scaleX = size.width / image.width;
    final double scaleY = size.height / image.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate the dimensions of the scaled image
    final double scaledWidth = image.width * scale;
    final double scaledHeight = image.height * scale;

    // Center the image within the destination rectangle
    final double dx = (size.width - scaledWidth) / 2;
    final double dy = (size.height - scaledHeight) / 2;

    final ui.Rect src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final ui.Rect dst = Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);

    // Draw the image
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant final CustomPainter oldDelegate) => false;
}
