import 'dart:typed_data';
import 'dart:ui' as ui;

/// Prepared source data reused across the lifetime of a smudge stroke.
class PreparedSmudgeStrokeSource {
  const PreparedSmudgeStrokeSource({
    required this.image,
    required this.pixels,
    required this.clipMask,
  });

  final ui.Image image;
  final Uint8List pixels;
  final Uint8List? clipMask;
}
