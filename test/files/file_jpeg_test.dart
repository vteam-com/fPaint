import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_jpeg.dart';
import 'package:fpaint/helpers/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileJpeg Tests', () {
    test('convertToJpg function exists and has correct signature', () {
      expect(convertToJpg, isNotNull);
    });

    test('convertToJpg encodes a captured raster directly', () async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      final ui.Paint paint = ui.Paint()..color = AppColors.white;
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), paint);

      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(1, 1);

      final Uint8List jpegBytes = await convertToJpg(image);
      expect(jpegBytes, isNotEmpty);
      expect(jpegBytes[0], 0xFF);
      expect(jpegBytes[1], 0xD8);
    });
  });
}
