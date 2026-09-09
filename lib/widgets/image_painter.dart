import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// A custom painter that displays an image, scaling and centering it to fit within the available space.
class ImagePainter extends CustomPainter {
  /// Creates an [ImagePainter] with the given image.
  ImagePainter(this.image);

  /// The image to paint.
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    // Thumbnails are swapped and freed asynchronously (a debounced rebuild, a
    // layer teardown), so the handle captured when this frame was scheduled can
    // already be released by the time it paints. Drawing it would trip
    // `assert(!image.debugDisposed)` in Canvas.drawImageRect; skipping the draw
    // leaves the transparency pattern showing for the one frame until the
    // replacement thumbnail notifies and repaints.
    //
    // `debugDisposed` throws a StateError when asserts are disabled, so the read
    // lives inside an assert block: in release the draw simply proceeds (the
    // engine tolerates it there — only the debug assert fires).
    bool isDisposed = false;
    assert(() {
      isDisposed = image.debugDisposed;
      return true;
    }());
    if (isDisposed) {
      return;
    }

    final ui.Paint paint = Paint();

    // Calculate the scale factors to fit the image into the destination rectangle
    final double scaleX = size.width / image.width;
    final double scaleY = size.height / image.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate the dimensions of the scaled image
    final double scaledWidth = image.width * scale;
    final double scaledHeight = image.height * scale;

    // Center the image within the destination rectangle
    final double dx = (size.width - scaledWidth) / AppMath.pair;
    final double dy = (size.height - scaledHeight) / AppMath.pair;

    final ui.Rect src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final ui.Rect dst = Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);

    // Draw the image
    canvas.drawImageRect(image, src, dst, paint);
  }

  /// Repaints when the widget hands over a different image.
  ///
  /// This must compare the image: returning a constant `false` makes Flutter
  /// keep the *old* painter (and its old [ui.Image] handle) when a rebuild
  /// supplies a new thumbnail. The layer then disposes that superseded texture
  /// and the retained painter draws a freed image on the next repaint.
  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) => !identical(oldDelegate.image, image);
}
