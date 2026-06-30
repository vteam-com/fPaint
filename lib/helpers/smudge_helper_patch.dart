part of 'smudge_helper.dart';

/// A small dirty-rect patch produced by [PixelBrushStrokeWorker] for one
/// segment. [pixels] are the RGBA bytes for the rect at [left]/[top] sized
/// [width] x [height] in image coordinates.
class PixelBrushPatchUpdate {
  const PixelBrushPatchUpdate({
    required this.pixels,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final Uint8List pixels;
  final int left;
  final int top;
  final int width;
  final int height;
}
