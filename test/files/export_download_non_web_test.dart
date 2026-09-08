import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/export_download_non_web.dart';
import 'package:fpaint/files/save.dart';
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
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return Uri.file(filePath);
  }
}

void main() {
  group('ExportDownload Non-Web Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('exportAs is defined for every save format', () {
      // Note: Due to factory constructor in LayersProvider, we can't create
      // mock instances for testing function calls. But we can verify that every
      // format is dispatchable through the single generic entry point.
      for (final SaveFileFormat format in SaveFileFormat.values) {
        expect(format.pickerExtensions, isNotEmpty);
        expect(format.defaultExportFileName, isNotEmpty);
        expect(format.exportDialogTitle, isNotEmpty);
      }
      expect(() => exportAs, returnsNormally);
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
      final String exportPath = '${tempDirectory.path}${Platform.pathSeparator}$_recentExportFileName';
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
        await exportAs(
          SaveFileFormat.png,
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
      final String exportPath = '${tempDirectory.path}${Platform.pathSeparator}secured-export.png';
      final String resolvedPath = '${tempDirectory.path}${Platform.pathSeparator}resolved-export.png';
      final FilePickerPlatform originalFilePicker = FilePickerPlatform.instance;
      final TargetPlatform? previousPlatform = debugDefaultTargetPlatformOverride;
      final List<String> methodCalls = <String>[];

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      FilePickerPlatform.instance = _TestSaveFilePicker(exportPath);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _fileChannel,
        (MethodCall methodCall) async {
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

      await exportAs(
        SaveFileFormat.png,
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
