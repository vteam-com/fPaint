import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/file_flow_harness.dart';
import 'psd_test_fixture.dart';

const int _pngWidth = 6;
const int _pngHeight = 4;
const int _fixtureSide = 5;
const String _newCanvasWidth = '20';
const String _newCanvasHeight = '10';
const ui.Size _newCanvasSize = ui.Size(20, 10);
const String _invalidSizeText = 'abc';
const String _tempDirPrefix = 'fpaint_import_flow_';
const String _pngName = 'picked.png';
const String _secondPngName = 'second.png';
const String _oraName = 'doc.ora';
const String _psdName = 'doc.psd';
const String _tiffName = 'doc.tif';
const String _heicName = 'broken.heic';
const String _missingHeicName = 'missing.heic';
const String _missingOraName = 'missing.ora';
const String _unsupportedName = 'notes.txt';
const String _corruptPngName = 'corrupt.png';
const String _pickerFailure = 'picker failed';
const List<int> _garbageBytes = <int>[0, 1, 2, 3, 4, 5, 6, 7];
const TestPsdColor _psdRed = TestPsdColor(255, 0, 0);
const int _rememberedLayerIndex = 0;

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(_tempDirPrefix);
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  String pathOf(String name) => '${tempDirectory.path}${Platform.pathSeparator}$name';

  Future<String> writeFixture(WidgetTester tester, String name, Future<List<int>> Function() bytes) async {
    final String path = pathOf(name);
    await tester.runAsync(() async => File(path).writeAsBytes(await bytes()));
    return path;
  }

  Future<String> writePng(WidgetTester tester, [String name = _pngName]) {
    return writeFixture(tester, name, () => encodeSolidPng(width: _pngWidth, height: _pngHeight));
  }

  AppLocalizations l10nOf(FileFlowHost host) => AppLocalizations.of(host.context)!;

  group('onFileNew', () {
    testWidgets('creates a canvas of the typed size and fits it', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);
      final AppLocalizations l10n = l10nOf(host);

      final Future<void> done = await startReal(tester, () => onFileNew(host.context));
      await pumpRealUntil(tester, () => find.text(l10n.newCanvasSize).evaluate().isNotEmpty);

      expect(find.text(l10n.newFromClipboard), findsNothing);
      final Finder fields = find.byType(EditableText);
      await tester.enterText(fields.first, _newCanvasWidth);
      await tester.enterText(fields.last, _newCanvasHeight);
      await tester.tap(find.text(l10n.create));
      await awaitReal(tester, done);

      expect(host.layers.size, _newCanvasSize);
      expect(host.fitRequests, greaterThan(0));
      await drainFileFlowTimers(tester);
    });

    testWidgets('rejects an invalid size, then cancels', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);
      final AppLocalizations l10n = l10nOf(host);
      final ui.Size initialSize = host.layers.size;

      final Future<void> done = await startReal(tester, () => onFileNew(host.context));
      await pumpRealUntil(tester, () => find.text(l10n.newCanvasSize).evaluate().isNotEmpty);

      await tester.enterText(find.byType(EditableText).first, _invalidSizeText);
      await tester.tap(find.text(l10n.create));
      await tester.pump();
      expect(find.text(l10n.invalidSize), findsOneWidget);

      await tester.tap(find.text(l10n.cancel));
      await awaitReal(tester, done);

      expect(find.text(l10n.newCanvasSize), findsNothing);
      expect(host.layers.size, initialSize);
      await drainFileFlowTimers(tester);
    });

    testWidgets('stops when the user keeps unsaved changes', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);
      final AppLocalizations l10n = l10nOf(host);
      host.layers.markAllChanged();

      final Future<void> done = await startReal(tester, () => onFileNew(host.context));
      await tester.tap(find.text(l10n.no));
      await awaitReal(tester, done);

      expect(find.text(l10n.newCanvasSize), findsNothing);
      await drainFileFlowTimers(tester);
    });
  });

  group('onFileOpen (desktop picker)', () {
    testWidgets('opens the picked PNG and records it as recent', (WidgetTester tester) async {
      final String path = await writePng(tester);
      installFilePicker(FakeFilePicker(pickedPath: path));
      final FileFlowHost host = await pumpFileFlowHost(tester);

      await runReal(tester, () => onFileOpen(host.context));

      expect(host.shell.loadedFileName, path);
      expect(host.layers.size, const ui.Size(_pngWidth * 1.0, _pngHeight * 1.0));
      expect(host.layers.hasChanged, isFalse);
      expect(host.preferences.recentFiles.first, path);
      expect(host.fitRequests, greaterThan(0));
      await drainFileFlowTimers(tester);
    });

    testWidgets('does nothing when the picker is cancelled', (WidgetTester tester) async {
      final FakeFilePicker picker = FakeFilePicker();
      installFilePicker(picker);
      final FileFlowHost host = await pumpFileFlowHost(tester);

      await runReal(tester, () => onFileOpen(host.context));

      expect(picker.pickCount, 1);
      expect(host.preferences.recentFiles, isEmpty);
      await drainFileFlowTimers(tester);
    });

    testWidgets('swallows picker failures', (WidgetTester tester) async {
      installFilePicker(FakeFilePicker(error: StateError(_pickerFailure)));
      final FileFlowHost host = await pumpFileFlowHost(tester);

      await runReal(tester, () => onFileOpen(host.context));

      expect(host.preferences.recentFiles, isEmpty);
      await drainFileFlowTimers(tester);
    });

    testWidgets('keeps the document when discarding is declined', (WidgetTester tester) async {
      final FakeFilePicker picker = FakeFilePicker(pickedPath: pathOf(_pngName));
      installFilePicker(picker);
      final FileFlowHost host = await pumpFileFlowHost(tester);
      host.layers.markAllChanged();

      final Future<void> done = await startReal(tester, () => onFileOpen(host.context));
      await tester.tap(find.text(l10nOf(host).no));
      await awaitReal(tester, done);

      expect(picker.pickCount, 0);
      await drainFileFlowTimers(tester);
    });
  });

  group('openFileFromPath', () {
    testWidgets('opens ORA, PSD and TIFF documents', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);
      final ui.Size fixtureSize = const ui.Size(_fixtureSide * 1.0, _fixtureSide * 1.0);
      final String oraPath = await writeFixture(tester, _oraName, () async {
        final LayersProvider source = LayersProvider()..size = fixtureSize;
        return createOraArchive(source, includePreviews: false);
      });
      final String tiffPath = await writeFixture(tester, _tiffName, () async {
        final LayersProvider source = LayersProvider()..size = fixtureSize;
        return convertLayersToTiff(source);
      });
      final String psdPath = await writeFixture(
        tester,
        _psdName,
        () async => buildTestPsd(
          width: _fixtureSide,
          height: _fixtureSide,
          layers: <TestPsdLayer>[
            const TestPsdLayer(
              name: _psdName,
              left: 0,
              top: 0,
              width: _fixtureSide,
              height: _fixtureSide,
              color: _psdRed,
            ),
          ],
        ),
      );

      for (final String path in <String>[oraPath, psdPath, tiffPath]) {
        host.layers.size = _newCanvasSize;
        final bool opened = await runReal(
          tester,
          () => openFileFromPath(context: host.context, layers: host.layers, path: path),
        );
        expect(opened, isTrue, reason: path);
        expect(host.layers.size, fixtureSize, reason: path);
      }
      await drainFileFlowTimers(tester);
    });

    testWidgets('restores the remembered selection of a flat file', (WidgetTester tester) async {
      final String path = await writePng(tester);
      final FileFlowHost host = await pumpFileFlowHost(tester);
      await tester.runAsync(() => host.preferences.recordLastSelectedLayer(path, _rememberedLayerIndex));

      final bool opened = await runReal(
        tester,
        () => openFileFromPath(
          context: host.context,
          layers: host.layers,
          path: path,
          preferences: host.preferences,
        ),
      );

      expect(opened, isTrue);
      expect(host.layers.selectedLayerIndex, _rememberedLayerIndex);
      await drainFileFlowTimers(tester);
    });

    testWidgets('reports unsupported, undecodable and missing files', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);
      final String heicPath = await writeFixture(tester, _heicName, () async => _garbageBytes);

      for (final String path in <String>[
        pathOf(_unsupportedName),
        heicPath,
        pathOf(_missingHeicName),
        pathOf(_missingOraName),
      ]) {
        final bool opened = await runReal(
          tester,
          () => openFileFromPath(
            context: host.context,
            layers: host.layers,
            path: path,
            preferences: host.preferences,
          ),
        );
        expect(opened, isFalse, reason: path);
      }
      await drainFileFlowTimers(tester);
    });
  });

  group('onFileDropped', () {
    Future<void> addContent(WidgetTester tester, FileFlowHost host) async {
      await tester.runAsync(() async {
        final ui.Image image = await fromBytesToImage(await encodeSolidPng(width: _pngWidth, height: _pngHeight));
        host.layers.selectedLayer.addImage(imageToAdd: image);
      });
    }

    testWidgets('rejects unsupported files', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);

      await runReal(tester, () => onFileDropped(context: host.context, path: pathOf(_unsupportedName)));

      expect(host.preferences.recentFiles, isEmpty);
      await drainFileFlowTimers(tester);
    });

    testWidgets('opens directly onto an empty canvas', (WidgetTester tester) async {
      final String path = await writePng(tester);
      final FileFlowHost host = await pumpFileFlowHost(tester);

      await runReal(tester, () => onFileDropped(context: host.context, path: path));

      expect(host.shell.loadedFileName, path);
      expect(host.preferences.recentFiles.first, path);
      await drainFileFlowTimers(tester);
    });

    testWidgets('adds the file as a layer when chosen', (WidgetTester tester) async {
      final String path = await writePng(tester);
      final FileFlowHost host = await pumpFileFlowHost(tester);
      await addContent(tester, host);
      final int layerCount = host.layers.length;

      final Future<void> done = await startReal(tester, () => onFileDropped(context: host.context, path: path));
      expect(find.text(l10nOf(host).dropFilePrompt), findsOneWidget);
      await tester.tap(find.text(l10nOf(host).dropFileAddLayer));
      await awaitReal(tester, done);

      expect(host.layers.length, layerCount + 1);
      expect(host.layers.get(0).name, _pngName);
      expect(host.preferences.recentFiles, isEmpty);
      await drainFileFlowTimers(tester);
    });

    testWidgets('replaces the document when Open is chosen', (WidgetTester tester) async {
      final String path = await writePng(tester, _secondPngName);
      final FileFlowHost host = await pumpFileFlowHost(tester);
      await addContent(tester, host);

      final Future<void> done = await startReal(tester, () => onFileDropped(context: host.context, path: path));
      await tester.tap(find.text(l10nOf(host).dropFileOpen));
      await awaitReal(tester, done);

      expect(host.shell.loadedFileName, path);
      expect(host.layers.length, 1);
      await drainFileFlowTimers(tester);
    });
  });

  group('byte and layer readers', () {
    testWidgets('addFileAsLayer reports unreadable images', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);
      final String corruptPath = await writeFixture(tester, _corruptPngName, () async => _garbageBytes);
      final int layerCount = host.layers.length;

      await runReal(tester, () => addFileAsLayer(context: host.context, layers: host.layers, path: corruptPath));

      expect(host.layers.length, layerCount);
      await drainFileFlowTimers(tester);
    });

    testWidgets('addFileAsLayer flattens a layered ORA into one new layer', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);
      final String oraPath = await writeFixture(tester, _oraName, () async {
        final LayersProvider source = LayersProvider()..size = const ui.Size(_fixtureSide * 1.0, _fixtureSide * 1.0);
        source.addTop(name: _psdName);
        return createOraArchive(source, includePreviews: false);
      });
      final int layerCount = host.layers.length;
      final ui.Size canvasSize = host.layers.size;

      await runReal(tester, () => addFileAsLayer(context: host.context, layers: host.layers, path: oraPath));

      expect(host.layers.length, layerCount + 1);
      expect(host.layers.selectedLayer.name, _oraName);
      expect(host.layers.size, canvasSize, reason: 'adding a layer must not resize the canvas');
      await drainFileFlowTimers(tester);
    });
  });

  // Seeds the process-wide session clipboard, so it must run last.
  testWidgets('onFileNew offers and performs New from clipboard', (WidgetTester tester) async {
    final FileFlowHost host = await pumpFileFlowHost(tester);
    final AppLocalizations l10n = l10nOf(host);
    await tester.runAsync(() async {
      await copyImageBytesToClipboard(await encodeSolidPng(width: _pngWidth, height: _pngHeight));
    });

    final Future<void> done = await startReal(tester, () => onFileNew(host.context));
    await pumpRealUntil(tester, () => find.text(l10n.newFromClipboard).evaluate().isNotEmpty);
    await tester.tap(find.text(l10n.newFromClipboard));
    await awaitReal(tester, done);
    await pumpRealUntil(tester, () => host.layers.size == const ui.Size(_pngWidth * 1.0, _pngHeight * 1.0));

    expect(host.layers.size, const ui.Size(_pngWidth * 1.0, _pngHeight * 1.0));
    expect(host.app, isA<AppProvider>());
    await drainFileFlowTimers(tester);
  });
}
