import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/package_image_bridge.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:image/image.dart' as img;

const int _width = 2;
const int _height = 1;

/// Two straight-RGBA pixels: opaque red and half-transparent green.
final List<int> _straightPixels = <int>[255, 0, 0, 255, 0, 200, 0, 128];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('packageImageFromRgbaBytes copies straight RGBA pixels', () {
    final Uint8List rgba = Uint8List.fromList(_straightPixels);
    final img.Image image = packageImageFromRgbaBytes(rgba, _width, _height);

    rgba[0] = 0;

    expect(image.width, _width);
    expect(image.height, _height);
    expect(image.numChannels, 4);
    expect(image.getPixel(0, 0).r, 255);
    expect(image.getPixel(1, 0).a, 128);
  });

  test('toRgba8PackageImage keeps RGBA8 images and converts others', () {
    final img.Image rgba = img.Image(width: _width, height: _height, numChannels: 4);
    expect(identical(toRgba8PackageImage(rgba), rgba), isTrue);

    final img.Image rgb = img.Image(width: _width, height: _height)..setPixelRgb(0, 0, 10, 20, 30);
    final img.Image converted = toRgba8PackageImage(rgb);
    expect(converted.numChannels, 4);
    expect(converted.format, img.Format.uint8);
    expect(converted.getPixel(0, 0).a, 255);
    expect(converted.getPixel(0, 0).g, 20);
  });

  test('packageImageToUiImage round-trips through uiImageToPackageImage', () async {
    final img.Image source = packageImageFromRgbaBytes(Uint8List.fromList(_straightPixels), _width, _height);

    final ui.Image uiImage = await packageImageToUiImage(source);
    final img.Image? roundTripped = await uiImageToPackageImage(uiImage);

    // The source pixels must not be premultiplied in place by the upload.
    expect(source.getPixel(1, 0).g, 200);
    expect(roundTripped, isNotNull);
    expect(roundTripped!.width, _width);
    expect(roundTripped.height, _height);
    expect(roundTripped.getPixel(0, 0).r, 255);
    expect(roundTripped.getPixel(1, 0).a, 128);
    expect((roundTripped.getPixel(1, 0).g.toInt() - 200).abs(), lessThanOrEqualTo(1));
    expect(await extractImagePixels(uiImage), isNotNull);
  });
}
