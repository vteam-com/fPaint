import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

const MethodChannel _fileChannel = MethodChannel('com.vteam.fpaint/file');
const String _pickedBookmark = 'synology-bookmark';
const int _imageSide = 4;
final TargetPlatformVariant _iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

/// Encodes a small opaque PNG for the picker to "return".
Future<Uint8List> _encodePng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFF3366CC), ui.BlendMode.src);
  final ui.Image image = await recorder.endRecording().toImage(_imageSide, _imageSide);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  late Directory tempDirectory;
  late String pickedPath;
  late List<String> methodCalls;
  late Object? pickResponse;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('fpaint_open_in_place_test');
    pickedPath = '${tempDirectory.path}/drawing.png';
    methodCalls = <String>[];
    pickResponse = <String, String>{'path': pickedPath, 'bookmark': _pickedBookmark};
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _fileChannel,
      (MethodCall methodCall) async {
        methodCalls.add(methodCall.method);
        switch (methodCall.method) {
          case 'pickDocumentInPlace':
            return pickResponse;
          case 'resolveBookmark':
            return pickedPath;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_fileChannel, null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<
    ({
      BuildContext context,
      ShellProvider shell,
      LayersProvider layers,
      AppPreferences preferences,
    })
  >
  pumpHost(WidgetTester tester) async {
    final ShellProvider shell = ShellProvider();
    final LayersProvider layers = LayersProvider();
    final AppPreferences preferences = AppPreferences();
    await tester.runAsync(preferences.getPref);
    late BuildContext hostContext;
    await tester.pumpWidget(
      InheritedControllerScope<ShellProvider>(
        controller: shell,
        child: InheritedControllerScope<LayersProvider>(
          controller: layers,
          child: InheritedControllerScope<AppPreferences>(
            controller: preferences,
            child: buildLocalizedScaffoldTestApp(
              bodyBuilder: (BuildContext context) {
                hostContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    return (context: hostContext, shell: shell, layers: layers, preferences: preferences);
  }

  testWidgets('iOS opens the picked document in place and keeps its bookmark', (WidgetTester tester) async {
    await tester.runAsync(() async => File(pickedPath).writeAsBytes(await _encodePng()));
    final ({BuildContext context, ShellProvider shell, LayersProvider layers, AppPreferences preferences}) host =
        await pumpHost(tester);

    await tester.runAsync(() => onFileOpen(host.context));

    expect(methodCalls, <String>['pickDocumentInPlace', 'resolveBookmark', 'releaseBookmark']);
    expect(host.shell.loadedFileName, pickedPath);
    expect(host.preferences.recentFiles.first, pickedPath);
    expect(host.preferences.getBookmark(pickedPath), _pickedBookmark);
    expect(host.layers.size, const ui.Size(_imageSide * 1.0, _imageSide * 1.0));
  }, variant: _iOS);

  testWidgets('iOS leaves the canvas untouched when the picker is cancelled', (WidgetTester tester) async {
    pickResponse = null;
    final ({BuildContext context, ShellProvider shell, LayersProvider layers, AppPreferences preferences}) host =
        await pumpHost(tester);
    final String initialFileName = host.shell.loadedFileName;

    await tester.runAsync(() => onFileOpen(host.context));

    expect(methodCalls, <String>['pickDocumentInPlace']);
    expect(host.shell.loadedFileName, initialFileName);
    expect(host.preferences.recentFiles, isEmpty);
  }, variant: _iOS);
}
