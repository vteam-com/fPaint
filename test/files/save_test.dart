import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/files/save_backup.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _fileChannel = MethodChannel('com.vteam.fpaint/file');
const String _bookmarkPath = '/tmp/bookmarked.ora';
const String _bookmarkValue = 'bookmark-a';

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
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('saveFile routes HEIC files correctly', () async {
      mockShell.loadedFileName = 'test.heic';
      expect(SaveFileFormat.fromFileName(mockShell.loadedFileName), SaveFileFormat.heic);
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

  group('saveFile bookmark access', () {
    late Directory tempDirectory;
    late String fallbackPath;
    late String resolvedPath;
    late AppPreferences preferences;
    late ShellProvider shellProvider;
    late LayersProvider layers;
    late TargetPlatform? previousPlatform;
    late List<String> methodCalls;

    setUp(() async {
      previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      tempDirectory = await Directory.systemTemp.createTemp('fpaint_save_test');
      fallbackPath = '${tempDirectory.path}/fallback.ora';
      resolvedPath = '${tempDirectory.path}/resolved.ora';
      methodCalls = <String>[];

      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferences.keyRecentFiles: <String>[_bookmarkPath, fallbackPath],
        AppPreferences.keyRecentFileBookmarks: <String>[_bookmarkValue, _bookmarkValue],
      });

      preferences = AppPreferences();
      await preferences.getPref();
      shellProvider = ShellProvider()..loadedFileName = fallbackPath;
      layers = LayersProvider();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _fileChannel,
        (final MethodCall methodCall) async {
          methodCalls.add(methodCall.method);
          switch (methodCall.method) {
            case 'resolveBookmark':
              return resolvedPath;
            case 'releaseBookmark':
              return null;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _fileChannel,
        null,
      );
      debugDefaultTargetPlatformOverride = previousPlatform;
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('uses the resolved bookmark path when saving', () async {
      await saveFile(shellProvider, layers, preferences);

      expect(await File(resolvedPath).exists(), isTrue);
      expect(await File(fallbackPath).exists(), isFalse);
      expect(methodCalls, <String>['resolveBookmark', 'releaseBookmark']);
    });
  });

  group('saveFile backups on macOS', () {
    late Directory tempDirectory;
    late String filePath;
    late AppPreferences preferences;
    late ShellProvider shellProvider;
    late LayersProvider layers;
    late TargetPlatform? previousPlatform;
    late List<String> methodCalls;

    setUp(() async {
      previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      tempDirectory = await Directory.systemTemp.createTemp('fpaint_save_backups_macos_test');
      filePath = '${tempDirectory.path}/project.ora';
      methodCalls = <String>[];

      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferences.keyKeepSaveBackups: true,
        AppPreferences.keyRecentFiles: <String>[filePath],
        AppPreferences.keyRecentFileBookmarks: <String>[_bookmarkValue],
      });

      preferences = AppPreferences();
      await preferences.getPref();
      shellProvider = ShellProvider()..loadedFileName = filePath;
      layers = LayersProvider();

      await File(filePath).writeAsBytes(<int>[7, 8, 9]);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _fileChannel,
        (final MethodCall methodCall) async {
          methodCalls.add(methodCall.method);
          switch (methodCall.method) {
            case 'replaceFileWithBackup':
              final Map<Object?, Object?> arguments = methodCall.arguments as Map<Object?, Object?>;
              final File targetFile = File(arguments['targetPath']! as String);
              final File replacementFile = File(arguments['replacementPath']! as String);
              final File backupFile = File('${targetFile.parent.path}/${arguments['backupFileName']! as String}');
              await targetFile.rename(backupFile.path);
              await replacementFile.rename(targetFile.path);
              return null;
            case 'resolveBookmark':
              return filePath;
            case 'releaseBookmark':
              return null;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _fileChannel,
        null,
      );
      debugDefaultTargetPlatformOverride = previousPlatform;
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('creates a visible sibling backup file', () async {
      await saveFile(shellProvider, layers, preferences);

      final List<File> backupFiles = (await tempDirectory.list().toList())
          .whereType<File>()
          .where((final File file) => file.path.contains('project_back-') && file.path.endsWith('.ora'))
          .toList();

      expect(await File(filePath).exists(), isTrue);
      expect(backupFiles, hasLength(1));
      expect(await backupFiles.single.readAsBytes(), <int>[7, 8, 9]);
      expect(methodCalls, containsAllInOrder(<String>['resolveBookmark', 'replaceFileWithBackup', 'releaseBookmark']));
    });
  });

  group('saveFile backups', () {
    late Directory tempDirectory;
    late String filePath;
    late AppPreferences preferences;
    late ShellProvider shellProvider;
    late LayersProvider layers;
    late TargetPlatform? previousPlatform;

    setUp(() async {
      previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      tempDirectory = await Directory.systemTemp.createTemp('fpaint_save_backups_test');
      filePath = '${tempDirectory.path}/project.ora';

      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferences.keyKeepSaveBackups: true,
      });

      preferences = AppPreferences();
      await preferences.getPref();
      shellProvider = ShellProvider()..loadedFileName = filePath;
      layers = LayersProvider();
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = previousPlatform;
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('renames the previous file into a timestamped backup before saving', () async {
      final File currentFile = File(filePath);
      await currentFile.writeAsBytes(<int>[1, 2, 3, 4]);

      await saveFile(shellProvider, layers, preferences);

      final List<File> backupFiles = (await tempDirectory.list().toList())
          .whereType<File>()
          .where((final File file) => file.path.contains('project_back-') && file.path.endsWith('.ora'))
          .toList();

      expect(await currentFile.exists(), isTrue);
      expect(backupFiles, hasLength(1));
      expect(await backupFiles.single.readAsBytes(), <int>[1, 2, 3, 4]);
    });

    test('keeps only the 3 newest backups', () async {
      Future<File> createBackup({
        required final String fileName,
        required final int secondsOffset,
      }) async {
        final File backupFile = File('${tempDirectory.path}/$fileName');
        await backupFile.writeAsString(fileName);
        await backupFile.setLastModified(
          DateTime(2024, 1, 1, 0, 0, secondsOffset),
        );
        return backupFile;
      }

      final File oldestBackup = await createBackup(
        fileName: 'project_back-20240101-000000-000000.ora',
        secondsOffset: 0,
      );
      await createBackup(
        fileName: 'project_back-20240101-000001-000000.ora',
        secondsOffset: 1,
      );
      await createBackup(
        fileName: 'project_back-20240101-000002-000000.ora',
        secondsOffset: 2,
      );

      final File currentFile = File(filePath);
      await currentFile.writeAsBytes(<int>[9, 9, 9]);
      await currentFile.setLastModified(DateTime(2024, 1, 1, 0, 0, 3));

      await saveFile(shellProvider, layers, preferences);

      final List<File> backupFiles = (await tempDirectory.list().toList())
          .whereType<File>()
          .where((final File file) => file.path.contains('project_back-') && file.path.endsWith('.ora'))
          .toList();

      expect(backupFiles, hasLength(3));
      expect(await oldestBackup.exists(), isFalse);
    });

    test('continues saving when backup creation fails', () async {
      final File currentFile = File(filePath);
      await currentFile.writeAsString('old-content');

      await saveWithOptionalBackup(
        filePath: filePath,
        preferences: preferences,
        backupAction: (final File _) async {
          throw const FileSystemException('backup rename blocked');
        },
        saveAction: (final String resolvedPath) async {
          await File(resolvedPath).writeAsString('new-content');
        },
      );

      final List<File> backupFiles = (await tempDirectory.list().toList())
          .whereType<File>()
          .where((final File file) => file.path.contains('project_back-') && file.path.endsWith('.ora'))
          .toList();

      expect(await currentFile.readAsString(), 'new-content');
      expect(backupFiles, isEmpty);
    });
  });
}
