import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/export_download_non_web.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _repeatExportCount = 4;
const String _recentExportFileName = 'recent-export.png';
const String _recentExportTestDirectoryPrefix = 'fpaint_export_recent_';

class _TestSaveFilePicker extends FilePickerPlatform {
  _TestSaveFilePicker(this.filePath);

  final String filePath;

  @override
  Future<String?> saveFile({
    final String? dialogTitle,
    final String? fileName,
    final String? initialDirectory,
    final FileType type = FileType.any,
    final List<String>? allowedExtensions,
    final Uint8List? bytes,
    final bool lockParentWindow = false,
  }) async {
    return filePath;
  }
}

void main() {
  group('ExportDownload Non-Web Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('onExportAsPng function exists', () {
      // Note: Due to factory constructor in LayersProvider, we can't create
      // mock instances for testing function calls. But we can verify function existence.
      expect(() => onExportAsPng, returnsNormally);
    });

    test('onExportAsJpeg function exists', () {
      expect(() => onExportAsJpeg, returnsNormally);
    });

    test('onExportAsOra function exists', () {
      expect(() => onExportAsOra, returnsNormally);
    });

    test('onExportAsTiff function exists', () {
      expect(() => onExportAsTiff, returnsNormally);
    });

    test('saveAsPng function exists', () {
      expect(() => saveAsPng, returnsNormally);
    });

    test('saveAsJpeg function exists', () {
      expect(() => saveAsJpeg, returnsNormally);
    });

    test('saveAsOra function exists', () {
      expect(() => saveAsOra, returnsNormally);
    });

    test('saveAsTiff function exists', () {
      expect(() => saveAsTiff, returnsNormally);
    });

    test('adds exported files to recent items without duplicates', () async {
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      final AppProvider appProvider = AppProvider(preferences: preferences);
      final Directory tempDirectory = await Directory.systemTemp.createTemp(_recentExportTestDirectoryPrefix);
      final String exportPath = '${tempDirectory.path}/$_recentExportFileName';
      final FilePickerPlatform originalFilePicker = FilePickerPlatform.instance;

      FilePickerPlatform.instance = _TestSaveFilePicker(exportPath);
      addTearDown(() async {
        appProvider.dispose();
        FilePickerPlatform.instance = originalFilePicker;
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      for (int exportIndex = 0; exportIndex < _repeatExportCount; exportIndex++) {
        await onExportAsPng(
          appProvider.layers,
          preferences: preferences,
        );
      }

      expect(preferences.recentFiles, <String>[exportPath]);
      expect(await File(exportPath).exists(), isTrue);
    });

    // Due to LayersProvider having a factory constructor, we can't easily
    // create mock instances for testing function calls or parameter validation.
    // However, function existence tests ensure these functions are properly exported.

    // Note: Full integration testing of these export functions would require
    // extensive mocking of FilePicker.platform, file system operations, and
    // LayersProvider. These functions are designed around platform file dialogs
    // and are better tested through integration tests that exercise the full
    // export workflow. The tests above verify that all functions are properly
    // exported and accessible.
  });
}
