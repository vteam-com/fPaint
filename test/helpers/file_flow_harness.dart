import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test_harness.dart';

/// Opaque fill used for the PNG fixtures written by [encodeSolidPng].
const ui.Color fileFlowFixtureColor = ui.Color(0xFF3366CC);

/// Canvas size of a freshly pumped [FileFlowHost].
const ui.Size _defaultHostCanvasSize = ui.Size(8, 8);

/// Default MIME type of the platform save dialog.
const String _defaultSaveMimeType = 'application/octet-stream';

/// A picked file backed by a real path on disk.
final class FakePickedFile extends PlatformFile {
  FakePickedFile(this.filePath);

  /// Absolute path of the picked file.
  final String filePath;

  @override
  String get name => filePath.split(Platform.pathSeparator).last;

  @override
  Uri get uri => Uri.file(filePath);

  @override
  Never get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => null;

  @override
  Future<int?> length() async => File(filePath).length();

  @override
  Future<Uint8List> readAsBytes() => File(filePath).readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() => Stream<Uint8List>.fromFuture(readAsBytes());
}

/// A [FilePickerPlatform] whose open dialog answers with [pickedPath] (or
/// cancels when null) and optionally throws [error], and whose save dialog
/// answers with [savePath].
class FakeFilePicker extends FilePickerPlatform {
  FakeFilePicker({this.pickedPath, this.savePath, this.error});

  /// The destination returned by the save dialog; `null` simulates a cancel.
  String? savePath;

  /// The path returned by the open dialog; `null` simulates a cancel.
  String? pickedPath;

  /// When set, the open dialog throws this instead of answering.
  Object? error;

  /// Number of times the open dialog was shown.
  int pickCount = 0;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickCount++;
    final Object? pendingError = error;
    if (pendingError != null) {
      throw pendingError;
    }
    final String? path = pickedPath;
    return path == null ? null : FakePickedFile(path);
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = _defaultSaveMimeType,
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final String? path = savePath;
    return path == null ? null : Uri.file(path);
  }
}

/// Installs [picker] as the platform file picker for the current test.
void installFilePicker(FilePickerPlatform picker) {
  final FilePickerPlatform original = FilePickerPlatform.instance;
  FilePickerPlatform.instance = picker;
  addTearDown(() => FilePickerPlatform.instance = original);
}

/// Encodes a solid [width]x[height] PNG.
Future<Uint8List> encodeSolidPng({
  required int width,
  required int height,
  ui.Color color = fileFlowFixtureColor,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(color, ui.BlendMode.src);
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The providers and host context of a pumped file-flow test app.
class FileFlowHost {
  FileFlowHost({
    required this.preferences,
    required this.undo,
    required this.layers,
    required this.app,
    required this.shell,
  });

  /// Real preferences backed by mocked shared preferences.
  final AppPreferences preferences;

  /// The undo stack shared by [layers] and [app].
  final UndoProvider undo;

  /// The document layers.
  final LayersProvider layers;

  /// The app provider wrapping [layers].
  final AppProvider app;

  /// The shell provider (loaded file name, canvas-fit requests).
  final ShellProvider shell;

  /// The scaffold body context, below every provider scope.
  late BuildContext context;

  /// Number of canvas-fit requests observed on [shell].
  int fitRequests = 0;
}

/// Pumps a localized scaffold under AppProvider, LayersProvider, ShellProvider
/// and AppPreferences scopes, and returns the providers plus host context.
Future<FileFlowHost> pumpFileFlowHost(
  WidgetTester tester, {
  ui.Size canvasSize = _defaultHostCanvasSize,
  Widget Function(BuildContext context)? bodyBuilder,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppPreferences preferences = AppPreferences();
  await tester.runAsync(preferences.getPref);
  final UndoProvider undo = UndoProvider();
  final LayersProvider layers = LayersProvider(undoProvider: undo)..size = canvasSize;
  final AppProvider app = AppProvider(
    preferences: preferences,
    layersProvider: layers,
    undoProvider: undo,
  );
  final ShellProvider shell = ShellProvider();
  final FileFlowHost host = FileFlowHost(
    preferences: preferences,
    undo: undo,
    layers: layers,
    app: app,
    shell: shell,
  );
  shell.canvasFitRequestListenable.addListener(() => host.fitRequests++);
  layers.clearHasChanged();
  addTearDown(() {
    app.dispose();
    layers.dispose();
    undo.dispose();
  });

  await tester.pumpWidget(
    InheritedControllerScope<AppPreferences>(
      controller: preferences,
      child: InheritedControllerScope<AppProvider>(
        controller: app,
        child: InheritedControllerScope<LayersProvider>(
          controller: layers,
          child: InheritedControllerScope<ShellProvider>(
            controller: shell,
            child: buildLocalizedScaffoldTestApp(
              bodyBuilder: (BuildContext context) {
                host.context = context;
                return bodyBuilder?.call(context) ?? const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    ),
  );
  return host;
}

/// Lets real async work (file I/O, image decoding) started by the code under
/// test make progress, then settles the widget tree.
Future<void> settleRealAsync(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

/// Starts [action] in the real-async zone so its continuations (file I/O,
/// image decoding, platform channels) run on the real event loop, lets it run
/// until it blocks (on a dialog, say), then renders the resulting frames.
Future<Future<T>> startReal<T>(WidgetTester tester, Future<T> Function() action) async {
  late Future<T> started;
  await tester.runAsync(() async {
    started = action();
    await Future<void>.delayed(_realAsyncStartGrace);
  });
  await tester.pumpAndSettle();
  return started;
}

/// Awaits [future] (started with [startReal]) on the real event loop and
/// settles the tree.
Future<T> awaitReal<T>(WidgetTester tester, Future<T> future) async {
  late T result;
  await tester.runAsync(() async {
    result = await future;
  });
  await tester.pumpAndSettle();
  return result;
}

/// Runs [action] to completion on the real event loop and settles the tree.
Future<T> runReal<T>(WidgetTester tester, Future<T> Function() action) async {
  return awaitReal(tester, await startReal(tester, action));
}

/// Flushes the layers' debounced thumbnail rebuilds and any snack-bar timers
/// so no timer outlives the test.
Future<void> drainFileFlowTimers(WidgetTester tester) async {
  await tester.pump(AppDefaults.thumbnailDebounceDuration);
  await tester.pump(AppDefaults.fileImportFeedbackDuration);
  await tester.pumpAndSettle();
}

/// Real time a [startReal] action gets before its first frame is rendered.
const Duration _realAsyncStartGrace = Duration(milliseconds: 20);

/// Maximum number of real-async rounds [pumpRealUntil] waits for.
const int _realAsyncPollAttempts = 400;

/// Real time given to background work between [pumpRealUntil] polls.
const Duration _realAsyncPollStep = Duration(milliseconds: 10);

/// Alternates real-async waits and frame pumps until [condition] holds, for
/// fire-and-forget flows that do real file I/O or image decoding.
Future<void> pumpRealUntil(
  WidgetTester tester,
  bool Function() condition, {
  String reason = '',
}) async {
  for (int attempt = 0; attempt < _realAsyncPollAttempts; attempt++) {
    if (condition()) {
      return;
    }
    await tester.runAsync(() => Future<void>.delayed(_realAsyncPollStep));
    await tester.pump(_realAsyncPollStep);
  }
  fail('Condition never became true. $reason');
}
