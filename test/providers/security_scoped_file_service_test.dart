import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/security_scoped_file_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _fileChannel = MethodChannel('com.vteam.fpaint/file');
const String _pickedPath = '/private/var/mobile/Library/File Provider Storage/drawing.png';
const String _pickedBookmark = 'picked-bookmark';
const String _sourcePath = '/tmp/source.png';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TargetPlatform? previousPlatform;
  late List<MethodCall> methodCalls;
  late Object? pickResponse;

  setUp(() {
    previousPlatform = debugDefaultTargetPlatformOverride;
    methodCalls = <MethodCall>[];
    pickResponse = <String, String>{'path': _pickedPath, 'bookmark': _pickedBookmark};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _fileChannel,
      (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        switch (methodCall.method) {
          case 'pickDocumentInPlace':
            return pickResponse;
          case 'resolveBookmark':
            return _pickedPath;
          case 'getOpenedFileBookmark':
            return methodCall.arguments == _pickedPath ? _pickedBookmark : null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_fileChannel, null);
    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  group('in-place documents on iOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('are supported', () {
      expect(SecurityScopedFileService.supportsInPlaceDocuments, isTrue);
      expect(SecurityScopedFileService.supportsReplaceFileWithBackup, isFalse);
    });

    test('pickDocumentInPlace returns the picked path and bookmark', () async {
      final InPlaceDocument? document = await SecurityScopedFileService.pickDocumentInPlace();

      expect(document?.path, _pickedPath);
      expect(document?.bookmark, _pickedBookmark);
    });

    test('openedFileBookmark returns the bookmark of a document opened from Files', () async {
      expect(await SecurityScopedFileService.openedFileBookmark(_pickedPath), _pickedBookmark);
      expect(await SecurityScopedFileService.openedFileBookmark(_sourcePath), isNull);
    });

    test('pickDocumentInPlace returns null when the user cancels', () async {
      pickResponse = null;

      expect(await SecurityScopedFileService.pickDocumentInPlace(), isNull);
    });

    test('pickDocumentInPlace returns null for a malformed response', () async {
      pickResponse = <String, String>{'path': _pickedPath};

      expect(await SecurityScopedFileService.pickDocumentInPlace(), isNull);
    });

    test('createBookmark is left to the picker', () async {
      expect(await SecurityScopedFileService.createBookmark(_pickedPath), isNull);
      expect(methodCalls, isEmpty);
    });

    test('writeFileCoordinated sends the target and source paths', () async {
      await SecurityScopedFileService.writeFileCoordinated(targetPath: _pickedPath, sourcePath: _sourcePath);

      expect(methodCalls.single.method, 'writeFileCoordinated');
      expect(methodCalls.single.arguments, <String, String>{'sourcePath': _sourcePath, 'targetPath': _pickedPath});
    });

    test('withResolvedBookmark resolves and releases the bookmark', () async {
      final String usedPath = await SecurityScopedFileService.withResolvedBookmark<String>(
        bookmarkBase64: _pickedBookmark,
        fallbackPath: _pickedPath,
        action: (String path) async => path,
      );

      expect(usedPath, _pickedPath);
      expect(methodCalls.map((MethodCall call) => call.method), <String>['resolveBookmark', 'releaseBookmark']);
      expect(methodCalls.last.arguments, _pickedPath);
    });
  });

  group('in-place documents on other platforms', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('are not supported and never reach the channel', () async {
      expect(SecurityScopedFileService.supportsInPlaceDocuments, isFalse);
      expect(await SecurityScopedFileService.pickDocumentInPlace(), isNull);
      expect(await SecurityScopedFileService.openedFileBookmark(_pickedPath), isNull);
      expect(methodCalls, isEmpty);
    });
  });

  group('AppPreferences.addRecentFile', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('stores a supplied bookmark', () async {
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();

      await preferences.addRecentFile(_pickedPath, bookmark: _pickedBookmark);

      expect(preferences.getBookmark(_pickedPath), _pickedBookmark);
    });

    test('keeps an existing bookmark when re-added without one', () async {
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      await preferences.addRecentFile(_pickedPath, bookmark: _pickedBookmark);

      await preferences.addRecentFile(_pickedPath);

      expect(preferences.getBookmark(_pickedPath), _pickedBookmark);
    });
  });
}
