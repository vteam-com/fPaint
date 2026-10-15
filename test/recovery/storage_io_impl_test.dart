import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/recovery/draft_recovery_storage.dart';
import 'package:fpaint/recovery/storage_io_impl.dart' as storage_io;

const MethodChannel _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const String _supportDirectoryMethod = 'getApplicationSupportDirectory';
const String _tempDirPrefix = 'fpaint_draft_storage_';
const String _draftDirectoryName = 'draft_recovery';
const String _draftFileName = 'recovery.ora';
const String _chmodCommand = 'chmod';
const String _noPermissions = '000';
const String _ownerReadWrite = '600';
const List<int> _draftBytes = <int>[1, 2, 3, 4];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDirectory;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(_tempDirPrefix);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (MethodCall call) async => call.method == _supportDirectoryMethod ? supportDirectory.path : null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      null,
    );
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  File draftFile() => File(
    '${supportDirectory.path}${Platform.pathSeparator}$_draftDirectoryName${Platform.pathSeparator}$_draftFileName',
  );

  test('round-trips a draft through the application support directory', () async {
    final DraftRecoveryStorage storage = storage_io.create();

    expect(await storage.hasDraft(), isFalse);
    expect(await storage.readDraft(), isNull);

    await storage.writeDraft(Uint8List.fromList(_draftBytes));

    expect(await draftFile().exists(), isTrue);
    expect(await storage.hasDraft(), isTrue);
    expect(await storage.readDraft(), _draftBytes);

    await storage.deleteDraft();

    expect(await storage.hasDraft(), isFalse);
    await storage.deleteDraft();
  });

  test(
    'rethrows when the draft file cannot be read or written',
    () async {
      final DraftRecoveryStorage storage = storage_io.create();
      await storage.writeDraft(Uint8List.fromList(_draftBytes));
      // Strip every permission so both read and write fail on an existing file.
      await Process.run(_chmodCommand, <String>[_noPermissions, draftFile().path]);
      addTearDown(() => Process.run(_chmodCommand, <String>[_ownerReadWrite, draftFile().path]));

      expect(await storage.hasDraft(), isTrue);
      await expectLater(storage.readDraft(), throwsA(isA<FileSystemException>()));
      await expectLater(
        storage.writeDraft(Uint8List.fromList(_draftBytes)),
        throwsA(isA<FileSystemException>()),
      );
    },
    skip: Platform.isWindows,
  );
}
