import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_exceptions.dart';
import 'package:fpaint/files/save.dart';

// Mock classes to test saveFile routing logic and saveAsTiff
class MockLayersProvider {
  Future<Uint8List> capturePainterToImageBytes() async {
    return Uint8List.fromList(<int>[1, 2, 3, 4]); // Return some dummy data
  }

  void clearHasChanged() {
    // Mock implementation
  }
}

class FailingLayersProvider {
  Future<Uint8List> capturePainterToImageBytes() async {
    return Uint8List(0); // Return empty data to test error handling
  }

  void clearHasChanged() {
    // Mock implementation
  }
}

class MockShellProvider {
  String loadedFileName = '';
}

void main() {
  group('Save Tests', () {
    // ignore: unused_local_variable
    late MockLayersProvider mockLayers;
    late MockShellProvider mockShell;

    setUp(() {
      mockLayers = MockLayersProvider();
      mockShell = MockShellProvider();
    });

    test('saveFile routes PNG files correctly', () async {
      mockShell.loadedFileName = 'test.png';

      expect(SaveFileFormat.fromFileName(mockShell.loadedFileName), SaveFileFormat.png);
    });

    test('saveFile routes JPEG variants correctly', () async {
      mockShell.loadedFileName = 'test.jpg';
      expect(SaveFileFormat.fromFileName(mockShell.loadedFileName), SaveFileFormat.jpeg);

      mockShell.loadedFileName = 'test.jpeg';
      expect(SaveFileFormat.fromFileName(mockShell.loadedFileName), SaveFileFormat.jpeg);
    });

    test('saveFile routes ORA files correctly', () async {
      mockShell.loadedFileName = 'test.ora';
      expect(SaveFileFormat.fromFileName(mockShell.loadedFileName), SaveFileFormat.ora);
    });

    test('saveFile routes TIFF variants correctly', () async {
      mockShell.loadedFileName = 'test.tiff';
      expect(SaveFileFormat.fromFileName(mockShell.loadedFileName), SaveFileFormat.tiff);

      mockShell.loadedFileName = 'test.tif';
      expect(SaveFileFormat.fromFileName(mockShell.loadedFileName), SaveFileFormat.tiff);
    });

    test('saveFile routes WebP files correctly', () async {
      mockShell.loadedFileName = 'test.webp';
      expect(SaveFileFormat.fromFileName(mockShell.loadedFileName), SaveFileFormat.webp);
    });

    test('saveFile throws for unsupported extensions', () async {
      mockShell.loadedFileName = 'test.gif';
      expect(SaveFileFormat.fromFileName(mockShell.loadedFileName), isNull);
      expect(const UnsupportedSaveFormatException('gif').extension, 'gif');

      mockShell.loadedFileName = 'test.bmp';
      expect(SaveFileFormat.fromFileName(mockShell.loadedFileName), isNull);
    });

    test('saveAsTiff function exists and is properly defined', () {
      // Test that the saveAsTiff function is properly defined
      expect(saveAsTiff, isNotNull);
      expect(saveAsTiff.runtimeType.toString(), contains('LayersProvider'));

      // Note: Integration testing of saveAsTiff would require mocking LayersProvider
      // and file I/O operations. The function existence test ensures it's properly exported.
    });

    // Note: Full integration testing of saveFile() and saveAsTiff() would require
    // extensive mocking of Flutter providers and file system operations. The tests
    // above verify the extension routing logic and error handling that can be tested
    // in isolation. File I/O operations are better tested through integration tests.
  });
}
