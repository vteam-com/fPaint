import 'dart:io';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/export_download_non_web.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _fileChannel = MethodChannel('com.vteam.fpaint/file');
const String _bookmarkValue = 'bookmark-export';
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

    test('uses bookmark-resolved access when exporting on macOS', () async {
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      final AppProvider appProvider = AppProvider(preferences: preferences);
      final Directory tempDirectory = await Directory.systemTemp.createTemp(
        '${_recentExportTestDirectoryPrefix}bookmark_',
      );
      final String exportPath = '${tempDirectory.path}/secured-export.png';
      final String resolvedPath = '${tempDirectory.path}/resolved-export.png';
      final FilePickerPlatform originalFilePicker = FilePickerPlatform.instance;
      final TargetPlatform? previousPlatform = debugDefaultTargetPlatformOverride;
      final List<String> methodCalls = <String>[];

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      FilePickerPlatform.instance = _TestSaveFilePicker(exportPath);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _fileChannel,
        (final MethodCall methodCall) async {
          methodCalls.add(methodCall.method);
          switch (methodCall.method) {
            case 'createBookmark':
              return _bookmarkValue;
            case 'resolveBookmark':
              return resolvedPath;
            case 'releaseBookmark':
              return null;
            default:
              return null;
          }
        },
      );

      addTearDown(() async {
        appProvider.dispose();
        debugDefaultTargetPlatformOverride = previousPlatform;
        FilePickerPlatform.instance = originalFilePicker;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          _fileChannel,
          null,
        );
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      await onExportAsPng(
        appProvider.layers,
        preferences: preferences,
      );

      expect(await File(resolvedPath).exists(), isTrue);
      expect(await File(exportPath).exists(), isFalse);
      expect(methodCalls, containsAllInOrder(<String>['createBookmark', 'resolveBookmark', 'releaseBookmark']));
      expect(preferences.recentFiles, <String>[exportPath]);
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
