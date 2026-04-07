import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/image_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageHelper Tests', () {
    group('Function existence tests', () {
      test('core image helper functions exist', () {
        expect(getImageColors, isNotNull);
        expect(fromBytesToImage, isNotNull);
        expect(convertImageToUint8List, isNotNull);
      });

      test('clipboard-related functions exist', () {
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
        final Debouncer defaultDebouncer = Debouncer();
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
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(callCount, equals(0)); // Should not have executed yet

        // Wait for debounce duration
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(callCount, equals(1)); // Should have executed once
      });

      test('cancels pending operation', () async {
        int callCount = 0;
        void callback() => callCount++;

        debouncer.run(callback);
        debouncer.cancel();

        // Wait longer than debounce duration
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(callCount, equals(0)); // Should not have executed
      });

      test('restarts timer on new calls', () async {
        int callCount = 0;
        void callback() => callCount++;

        debouncer.run(callback);
        await Future<void>.delayed(const Duration(milliseconds: 50)); // Half way
        debouncer.run(callback); // Restart timer

        // Wait past first timer but before second
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(callCount, equals(0));

        // Wait for second timer to complete
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(callCount, equals(1));
      });
    });

    // Note: Complex image processing functions (getImageColors, fromBytesToImage, convertImageToUint8List,
    // copyImageToClipboard, resizeImage, cropImage)
    // are difficult to unit test due to their dependency on Flutter's Image/ui classes and
    // platform-specific operations. Integration tests would be more appropriate for these functions.
  });
}
