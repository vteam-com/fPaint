import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// Wraps a [Widget] in a transparent paper-like container with a rounded border.
///
/// The [transparentPaperContainer] function takes a [Widget] and returns a new [Widget] that is wrapped in a transparent paper-like container with a rounded border. The container has a transparent background with a subtle grid pattern, and the child [Widget] is centered within the container.
///
/// The [radius] parameter can be used to adjust the border radius of the container.
///
/// Example usage:
///
/// transparentPaperContainer(
///   Text('Hello, World!'),
///   radius: 16.0,
/// )
Widget transparentPaperContainer(
  Widget child, {
  double radius = AppRadius.medium,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Padding(
      padding: const EdgeInsets.all(AppStroke.thin),
      child: Stack(
        children: <Widget>[
          const TransparentPaper(patternSize: AppMath.bytesPerPixel),
          Container(
            alignment: Alignment.center,
            child: child,
          ),
        ],
      ),
    ),
  );
}

/// A widget that displays a transparent background with a grid pattern.
class TransparentPaper extends StatelessWidget {
  /// Creates a [TransparentPaper].
  const TransparentPaper({super.key, this.patternSize = AppLimits.transparentPatternSize});

  /// The size of the grid pattern.
  final int patternSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TransparentBackgroundPainter(patternSize),
    );
  }
}

/// A custom painter that draws a transparent background with a grid pattern.
class _TransparentBackgroundPainter extends CustomPainter {
  /// Creates a [_TransparentBackgroundPainter].
  _TransparentBackgroundPainter([this.patternSize = AppLimits.transparentPatternSize]);

  /// The size of the grid pattern.
  final int patternSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isFinite) {
      drawTransparentBackgroundOffsetAndSize(
        canvas: canvas,
        size: size,
        patternSize: patternSize,
      );
    }
  }

  @override
  bool shouldRepaint(_TransparentBackgroundPainter oldDelegate) => oldDelegate.patternSize != patternSize;
}

/// Draws a transparent background grid on the canvas.
/// The grid is composed of alternating grey squares of [patternSize] pixels,
/// anchored at [offset], clipped to the [offset] & [size] bounds, and filled
/// with the shared [checkerboardShader] in a single `drawRect`.
void drawTransparentBackgroundOffsetAndSize({
  required Canvas canvas,
  required Size size,
  Offset offset = Offset.zero,
  int patternSize = AppLimits.transparentPatternSize,
}) {
  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  final Rect containerRect = Offset.zero & size;
  canvas.clipRect(containerRect);
  canvas.drawRect(containerRect, Paint()..shader = checkerboardShader(patternSize: patternSize));
  canvas.restore();
}

/// Rasterized checkerboard tiles and their repeating shaders, one per
/// pattern size. The tile image is retained alongside its shader so it is
/// never finalized while the shader still samples it.
final Map<int, (ui.Image, ui.ImageShader)> _checkerboardCache = <int, (ui.Image, ui.ImageShader)>{};

/// Returns a repeating transparency checkerboard shader with square cells of
/// [patternSize] logical pixels: [AppColors.grey400] cells on an
/// [AppColors.grey300] ground, with a dark cell at the origin.
///
/// The two-by-two cell tile is rasterized once per [patternSize] and cached
/// for the life of the process, so filling any area is a single `drawRect`
/// rather than one `drawRect` per cell.
ui.ImageShader checkerboardShader({int patternSize = AppLimits.transparentPatternSize}) {
  final (ui.Image, ui.ImageShader)? cached = _checkerboardCache[patternSize];
  if (cached != null) {
    return cached.$2;
  }

  final int tile = patternSize * AppMath.pair;
  final double cellSize = patternSize.toDouble();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas tileCanvas = Canvas(recorder);
  tileCanvas.drawRect(
    Rect.fromLTWH(0, 0, tile.toDouble(), tile.toDouble()),
    Paint()..color = AppColors.grey300,
  );
  final Paint cellPaint = Paint()..color = AppColors.grey400;
  tileCanvas.drawRect(Rect.fromLTWH(0, 0, cellSize, cellSize), cellPaint);
  tileCanvas.drawRect(Rect.fromLTWH(cellSize, cellSize, cellSize, cellSize), cellPaint);

  final ui.Picture picture = recorder.endRecording();
  final ui.Image tileImage = picture.toImageSync(tile, tile);
  picture.dispose();
  final ui.ImageShader shader = ui.ImageShader(
    tileImage,
    TileMode.repeated,
    TileMode.repeated,
    Matrix4.identity().storage,
  );
  _checkerboardCache[patternSize] = (tileImage, shader);
  return shader;
}
