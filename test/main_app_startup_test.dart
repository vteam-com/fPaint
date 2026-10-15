import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/main.dart' as app;
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

const String _fileChannelName = 'com.vteam.fpaint/file';
const MethodChannel _fileChannel = MethodChannel(_fileChannelName);
const MethodChannel _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const String _supportDirectoryMethod = 'getApplicationSupportDirectory';
const String _getPendingFileMethod = 'getPendingFile';
const String _clearPendingFileMethod = 'clearPendingFile';
const String _fileOpenedMethod = 'fileOpened';
const String _quitRequestedMethod = 'quitRequested';
const String _unknownFileMethod = 'notAFileCommand';
const String _unknownEditMethod = 'notAnEditCommand';
const String _fileUrlScheme = 'file';
const String _malformedFileUrl = 'file://[';
const String _platformErrorCode = 'unavailable';
const String _tempDirPrefix = 'fpaint_main_startup_';
const String _firstImageName = 'launch image.png';
const String _secondImageName = 'second.png';
const int _testImageSize = 4;
const int _queuedFileCount = 2;
const Duration _modifiedTimeResolution = Duration(milliseconds: 1100);
const int _maxRealAsyncPolls = 100;
const Duration _realAsyncStep = Duration(milliseconds: 20);
const Duration _timerDrainWait = Duration(seconds: 5);
const StandardMethodCodec _codec = StandardMethodCodec();

void main() {
  late Directory tempDir;
  late String firstImagePath;
  late String secondImagePath;
  late List<String> fileChannelCalls;
  late AppLocalizations l10n;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = Directory.systemTemp.createTempSync(_tempDirPrefix);
    final List<int> pngBytes = img.encodePng(img.Image(width: _testImageSize, height: _testImageSize));
    firstImagePath = '${tempDir.path}/$_firstImageName';
    secondImagePath = '${tempDir.path}/$_secondImageName';
    File(firstImagePath).writeAsBytesSync(pngBytes);
    File(secondImagePath).writeAsBytesSync(pngBytes);
    fileChannelCalls = <String>[];
    l10n = await AppLocalizations.delegate.load(const Locale('en'));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (MethodCall call) async => call.method == _supportDirectoryMethod ? tempDir.path : null,
    );
  });

  tearDown(() {
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    messenger.setMockMethodCallHandler(_fileChannel, null);
    tempDir.deleteSync(recursive: true);
  });

  /// Lets real file I/O and image decoding progress between fake-async frames
  /// until [condition] holds.
  ///
  /// Each step also schedules a frame: the queued platform-file handler runs
  /// from a post-frame callback but does not request a frame itself, so it
  /// relies on the app producing one.
  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    for (int poll = 0; poll < _maxRealAsyncPolls && !condition(); poll++) {
      await tester.runAsync(() => Future<void>.delayed(_realAsyncStep));
      tester.binding.scheduleFrame();
      await tester.pump(_realAsyncStep);
    }
    expect(condition(), isTrue);
  }

  /// Delivers [method] to the app's file channel as the native side would and
  /// returns the decoded reply once the handler finishes.
  Future<Object?> sendFileChannelMessage(WidgetTester tester, String method, [Object? arguments]) {
    final Completer<Object?> reply = Completer<Object?>();
    unawaited(
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        _fileChannelName,
        _codec.encodeMethodCall(MethodCall(method, arguments)),
        (ByteData? data) => reply.complete(data == null ? null : _codec.decodeEnvelope(data)),
      ),
    );
    return reply.future;
  }

  /// Presses Cmd+[key] so the app-level shortcut scope handles it.
  Future<void> sendCommandChord(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
  }

  /// Runs out the recovery-draft debounce, thumbnail rebuilds and notifications.
  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pump(AppDefaults.recoverySaveDebounce);
    await tester.pump(_timerDrainWait);
  }

  testWidgets('platform file opening: launch queue, unsaved prompt, malformed URLs and quit', (
    WidgetTester tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_fileChannel, (MethodCall call) async {
      fileChannelCalls.add(call.method);
      if (call.method == _getPendingFileMethod) {
        return Uri(scheme: _fileUrlScheme, path: firstImagePath).toString();
      }
      return null;
    });

    await app.main();
    // Finder can deliver files before the first frame: they wait in the queue
    // and open one after another, and the matching pending launch file must
    // not open the first one twice.
    final Future<Object?> earlyOpen = sendFileChannelMessage(tester, _fileOpenedMethod, firstImagePath);
    unawaited(sendFileChannelMessage(tester, _fileOpenedMethod, secondImagePath));
    await tester.pump();
    expect(await earlyOpen, isNull);

    await pumpUntil(tester, () => app.mainApp.shellProvider.loadedFileName == secondImagePath);
    await pumpUntil(
      tester,
      () => fileChannelCalls.where((String method) => method == _clearPendingFileMethod).length == _queuedFileCount,
    );
    expect(fileChannelCalls.where((String method) => method == _getPendingFileMethod).length, 1);
    expect(app.mainApp.appPreferences.recentFiles, containsAll(<String>[firstImagePath, secondImagePath]));

    // Unsaved work: Cancel keeps the current document.
    app.mainApp.appProvider.layers.markAllChanged();
    unawaited(sendFileChannelMessage(tester, _fileOpenedMethod, firstImagePath));
    await tester.pumpAndSettle();
    expect(find.text(l10n.unsavedChangesDiscardAndOpenPrompt), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, l10n.cancel));
    await tester.pumpAndSettle();
    expect(app.mainApp.shellProvider.loadedFileName, secondImagePath);

    // Unsaved work: Discard and Open loads the new file.
    unawaited(sendFileChannelMessage(tester, _fileOpenedMethod, firstImagePath));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, l10n.discardAndOpen));
    await pumpUntil(tester, () => app.mainApp.shellProvider.loadedFileName == firstImagePath);

    // Cmd+S saves the loaded file in place through the app-level shortcut.
    final DateTime modifiedBeforeSave = File(firstImagePath).lastModifiedSync();
    await tester.runAsync(() => Future<void>.delayed(_modifiedTimeResolution));
    await sendCommandChord(tester, LogicalKeyboardKey.keyS);
    await pumpUntil(tester, () => File(firstImagePath).lastModifiedSync().isAfter(modifiedBeforeSave));

    // Cmd+N offers New from clipboard, which does nothing with no clipboard image.
    await sendCommandChord(tester, LogicalKeyboardKey.keyN);
    await tester.pump(AppDefaults.clipboardAccessTimeout);
    expect(app.mainApp.shellProvider.loadedFileName, firstImagePath);

    // A malformed file URL is passed through untouched and rejected as a
    // format the app cannot open; a failing native clear is tolerated.
    app.mainApp.appProvider.layers.clearHasChanged();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_fileChannel, (MethodCall call) async {
      fileChannelCalls.add(call.method);
      throw PlatformException(code: _platformErrorCode);
    });
    fileChannelCalls.clear();
    unawaited(sendFileChannelMessage(tester, _fileOpenedMethod, _malformedFileUrl));
    await pumpUntil(tester, () => fileChannelCalls.contains(_clearPendingFileMethod));
    expect(app.mainApp.shellProvider.loadedFileName, firstImagePath);

    // Quit is allowed straight through when nothing is unsaved; unknown
    // methods are ignored.
    final Future<Object?> quitReply = sendFileChannelMessage(tester, _quitRequestedMethod);
    await tester.pump();
    expect(await quitReply, isTrue);
    final Future<Object?> unknownReply = sendFileChannelMessage(tester, _unknownFileMethod);
    await tester.pump();
    expect(await unknownReply, isNull);

    await expectLater(
      app.handlePlatformEditMethodCall(const MethodCall(_unknownEditMethod)),
      throwsA(isA<MissingPluginException>()),
    );

    await drainTimers(tester);
  });

  testWidgets('a failing pending-file probe still checks for a recovery draft', (WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_fileChannel, (MethodCall call) async {
      fileChannelCalls.add(call.method);
      throw PlatformException(code: _platformErrorCode);
    });

    await app.main();
    await tester.pump();
    await pumpUntil(tester, () => fileChannelCalls.contains(_getPendingFileMethod));
    // Let the draft check's file probes finish.
    await tester.runAsync(() => Future<void>.delayed(_realAsyncStep));
    await tester.pump();

    expect(app.mainApp.shellProvider.loadedFileName, isEmpty);
    await drainTimers(tester);
  });

  testWidgets('without the native file plugin, startup and opening a file still work', (
    WidgetTester tester,
  ) async {
    await app.main();
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_realAsyncStep));
    await tester.pump();

    unawaited(sendFileChannelMessage(tester, _fileOpenedMethod, firstImagePath));
    await pumpUntil(tester, () => app.mainApp.shellProvider.loadedFileName == firstImagePath);

    await drainTimers(tester);
  });
}
