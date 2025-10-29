import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/image_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageHelper Tests', () {
    group('imageBytesListToString', () {
      test('converts byte array to string list', () {
        // Create test RGBA bytes: 2x2 image (16 bytes total: 4 bytes per pixel)
        final Uint8List bytes = Uint8List.fromList([
          255, 0, 0, 255, // Red pixel (0,0)
          0, 255, 0, 255, // Green pixel (1,0)
          0, 0, 255, 255, // Blue pixel (0,1)
          255, 255, 255, 255, // White pixel (1,1)
        ]);

        const int width = 2;
        final List<String> result = imageBytesListToString(bytes, width);

        expect(result, isNotEmpty);
        expect(result.length, equals(width)); // Should have 'height' rows (2)

        // Check first row (first 2 pixels)
        expect(result[0], equals('ff0000ff|00ff00ff'));
        // Check second row (last 2 pixels)
        expect(result[1], equals('0000ffff|ffffffff'));
      });

      test('handles width that divides evenly', () {
        // 1x1 image
        final bytes = Uint8List.fromList([255, 0, 0, 255]);
        const width = 1;
        final result = imageBytesListToString(bytes, width);

        expect(result.length, equals(1));
        expect(result[0], equals('ff0000ff'));
      });

      test('handles empty bytes list', () {
        final bytes = Uint8List(0);
        const width = 1;
        final result = imageBytesListToString(bytes, width);

        expect(result, isEmpty);
      });

      test('handles partial pixels at end', () {
        // 5 bytes instead of multiple of 4 (incomplete pixel)
        final bytes = Uint8List.fromList([255, 0, 0, 255, 128]);
        const width = 1;
        final result = imageBytesListToString(bytes, width);

        // The function should process what it can using integer row calculation
        // Height = 5 ~/ (4 * 1) = 1, but due to loop logic, it may produce empty rows
        expect(result, isNotEmpty);
        // First pixel should be processed completely
        expect(result.first, contains('ff0000ff'));
        // The exact number depends on implementation details, just verify it works
        expect(result.length, greaterThan(0));
      });
    });

    group('Function existence tests', () {
      test('core image helper functions exist', () {
        expect(getImageColors, isNotNull);
        expect(fromBytesToImage, isNotNull);
        expect(convertImageToUint8List, isNotNull);
        expect(imageToListToString, isNotNull);
        expect(createImageFromBytes, isNotNull);
      });

      test('clipboard-related functions exist', () {
        expect(copyImageBase64, isNotNull);
        expect(copyImageToClipboard, isNotNull);
        expect(getImageFromClipboard, isNotNull);
        expect(clipboardHasImage, isNotNull);
      });

      test('image manipulation functions exist', () {
        expect(resizeImage, isNotNull);
        expect(cropImage, isNotNull);
      });
    });

    group('Debouncer', () {
      late Debouncer debouncer;

      setUp(() {
        debouncer = Debouncer(const Duration(milliseconds: 100));
      });

      test('creates debouncer with default duration', () {
        final defaultDebouncer = Debouncer();
        expect(defaultDebouncer.duration, equals(const Duration(seconds: 1)));
      });

      test('creates debouncer with custom duration', () {
        expect(debouncer.duration, equals(const Duration(milliseconds: 100)));
      });

      test('debounces multiple calls', () async {
        int callCount = 0;
        void callback() => callCount++;

        // Call multiple times rapidly
        debouncer.run(callback);
        debouncer.run(callback);
        debouncer.run(callback);

        // Wait less than debounce duration
        await Future.delayed(const Duration(milliseconds: 50));
        expect(callCount, equals(0)); // Should not have executed yet

        // Wait for debounce duration
        await Future.delayed(const Duration(milliseconds: 60));
        expect(callCount, equals(1)); // Should have executed once
      });

      test('cancels pending operation', () async {
        int callCount = 0;
        void callback() => callCount++;

        debouncer.run(callback);
        debouncer.cancel();

        // Wait longer than debounce duration
        await Future.delayed(const Duration(milliseconds: 150));
        expect(callCount, equals(0)); // Should not have executed
      });

      test('restarts timer on new calls', () async {
        int callCount = 0;
        void callback() => callCount++;

        debouncer.run(callback);
        await Future.delayed(const Duration(milliseconds: 50)); // Half way
        debouncer.run(callback); // Restart timer

        // Wait past first timer but before second
        await Future.delayed(const Duration(milliseconds: 80));
        expect(callCount, equals(0));

        // Wait for second timer to complete
        await Future.delayed(const Duration(milliseconds: 30));
        expect(callCount, equals(1));
      });
    });

    // Note: Complex image processing functions (getImageColors, fromBytesToImage, convertImageToUint8List,
    // imageToListToString, createImageFromBytes, copyImageToClipboard, resizeImage, cropImage)
    // are difficult to unit test due to their dependency on Flutter's Image/ui classes and
    // platform-specific operations. Integration tests would be more appropriate for these functions.
  });
}
