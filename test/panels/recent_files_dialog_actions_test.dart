import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/recent_files_dialog.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/file_flow_harness.dart';

const int _pngWidth = 6;
const int _pngHeight = 4;
const ui.Size _pngSize = ui.Size(6, 4);
const int _clipboardSide = 3;
const String _tempDirPrefix = 'fpaint_recent_actions_';
const String _pngName = 'recent.png';
const String _oraName = 'recent.ora';
const String _corruptPngName = 'corrupt.png';
const String _corruptPsdName = 'corrupt.psd';
const String _missingName = 'gone.png';
const String _metadataFailure = 'metadata failed';
const String _pickerFailure = 'picker failed';
const int _decodableRecentCount = 2;
const int _undecodableRecentCount = 2;
const int _sheetTransitionFrames = 6;
const Duration _sheetTransitionStep = Duration(milliseconds: 100);
const List<int> _garbageBytes = <int>[0, 1, 2, 3, 4, 5, 6, 7];

/// Animates the bottom sheet in without waiting for spinners to settle.
Future<void> _pumpSheetTransition(WidgetTester tester) async {
  for (int frame = 0; frame < _sheetTransitionFrames; frame++) {
    await tester.pump(_sheetTransitionStep);
  }
}

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

  Future<String> writePng(WidgetTester tester) {
    return writeFixture(tester, _pngName, () => encodeSolidPng(width: _pngWidth, height: _pngHeight));
  }

  Future<void> addRecent(WidgetTester tester, FileFlowHost host, List<String> paths) async {
    for (final String path in paths.reversed) {
      await tester.runAsync(() => host.preferences.addRecentFile(path));
    }
  }

  /// Opens the shared import sheet from the host context.
  Future<AppLocalizations> openSheet(WidgetTester tester, FileFlowHost host) async {
    showImportSheet(host.context);
    await _pumpSheetTransition(tester);
    expect(find.byType(ImportDialog), findsOneWidget);
    return AppLocalizations.of(host.context)!;
  }

  Future<void> enableAddAsLayer(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(find.text(l10n.addAsNewLayer));
    await tester.pump();
  }

  testWidgets('default loaders show thumbnails, metadata and failure placeholders', (WidgetTester tester) async {
    final String pngPath = await writePng(tester);
    final String oraPath = await writeFixture(tester, _oraName, () async {
      final LayersProvider source = LayersProvider()..size = _pngSize;
      return createOraArchive(source);
    });
    final String corruptPngPath = await writeFixture(tester, _corruptPngName, () async => _garbageBytes);
    final String corruptPsdPath = await writeFixture(tester, _corruptPsdName, () async => _garbageBytes);
    final String missingPath = pathOf(_missingName);
    final FileFlowHost host = await pumpFileFlowHost(tester);
    await addRecent(tester, host, <String>[pngPath, oraPath, corruptPngPath, corruptPsdPath, missingPath]);

    final AppLocalizations l10n = await openSheet(tester, host);
    await pumpRealUntil(
      tester,
      () =>
          find.byType(RawImage).evaluate().length == _decodableRecentCount &&
          find.text(l10n.previewUnavailable).evaluate().length == _undecodableRecentCount &&
          find.text(l10n.fileNotFound).evaluate().isNotEmpty,
      reason: 'thumbnails and placeholders',
    );

    expect(find.text(_pngName), findsOneWidget);
    expect(find.text(_missingName), findsOneWidget);
    await drainFileFlowTimers(tester);
  });

  testWidgets('tapping a recent file opens it in place of the document', (WidgetTester tester) async {
    final String pngPath = await writePng(tester);
    final FileFlowHost host = await pumpFileFlowHost(tester);
    await addRecent(tester, host, <String>[pngPath]);

    await openSheet(tester, host);
    await tester.tap(find.text(_pngName));
    await pumpRealUntil(tester, () => host.shell.loadedFileName == pngPath);
    await _pumpSheetTransition(tester);

    expect(find.byType(ImportDialog), findsNothing);
    expect(host.layers.size, _pngSize);
    expect(host.layers.hasChanged, isFalse);
    await drainFileFlowTimers(tester);
  });

  testWidgets('a recent file that fails to open reports a read error', (WidgetTester tester) async {
    final String missingPath = pathOf(_missingName);
    final FileFlowHost host = await pumpFileFlowHost(tester);
    await addRecent(tester, host, <String>[missingPath]);

    final AppLocalizations l10n = await openSheet(tester, host);
    await tester.tap(find.text(_missingName));
    await pumpRealUntil(tester, () => find.text(l10n.errorReadingFile(missingPath)).evaluate().isNotEmpty);

    expect(host.shell.loadedFileName, isNot(missingPath));
    await drainFileFlowTimers(tester);
  });

  testWidgets('declining discard keeps the document when opening a recent file', (WidgetTester tester) async {
    final String pngPath = await writePng(tester);
    final FileFlowHost host = await pumpFileFlowHost(tester);
    await addRecent(tester, host, <String>[pngPath]);
    host.layers.markAllChanged();

    final AppLocalizations l10n = await openSheet(tester, host);
    await tester.tap(find.text(_pngName));
    await settleRealAsync(tester);
    await tester.tap(find.text(l10n.no));
    await settleRealAsync(tester);

    expect(host.shell.loadedFileName, isNot(pngPath));
    await drainFileFlowTimers(tester);
  });

  testWidgets('tapping a recent file in add-as-layer mode stacks it on top', (WidgetTester tester) async {
    final String pngPath = await writePng(tester);
    final FileFlowHost host = await pumpFileFlowHost(tester);
    await addRecent(tester, host, <String>[pngPath]);
    final int layerCount = host.layers.length;

    final AppLocalizations l10n = await openSheet(tester, host);
    await enableAddAsLayer(tester, l10n);
    await tester.tap(find.text(_pngName));
    await pumpRealUntil(tester, () => host.layers.length == layerCount + 1);

    expect(host.layers.get(0).name, _pngName);
    expect(host.preferences.recentFiles.first, pngPath);
    await drainFileFlowTimers(tester);
  });

  testWidgets('Browse opens the picked file', (WidgetTester tester) async {
    final String pngPath = await writePng(tester);
    installFilePicker(FakeFilePicker(pickedPath: pngPath));
    final FileFlowHost host = await pumpFileFlowHost(tester);

    final AppLocalizations l10n = await openSheet(tester, host);
    await tester.tap(find.text(l10n.browseFiles));
    await pumpRealUntil(tester, () => host.preferences.recentFiles.contains(pngPath));

    expect(host.shell.loadedFileName, pngPath);
    await drainFileFlowTimers(tester);
  });

  testWidgets('Browse in add-as-layer mode adds the picked file as a layer', (WidgetTester tester) async {
    final String pngPath = await writePng(tester);
    installFilePicker(FakeFilePicker(pickedPath: pngPath));
    final FileFlowHost host = await pumpFileFlowHost(tester);
    final int layerCount = host.layers.length;

    final AppLocalizations l10n = await openSheet(tester, host);
    await enableAddAsLayer(tester, l10n);
    await tester.tap(find.text(l10n.browseFiles));
    await pumpRealUntil(tester, () => host.preferences.recentFiles.contains(pngPath));

    expect(host.layers.length, layerCount + 1);
    await drainFileFlowTimers(tester);
  });

  testWidgets('Browse in add-as-layer mode reports picker failures', (WidgetTester tester) async {
    installFilePicker(FakeFilePicker(error: StateError(_pickerFailure)));
    final FileFlowHost host = await pumpFileFlowHost(tester);

    final AppLocalizations l10n = await openSheet(tester, host);
    await enableAddAsLayer(tester, l10n);
    await tester.tap(find.text(l10n.browseFiles));
    await pumpRealUntil(tester, () => find.textContaining(_pickerFailure).evaluate().isNotEmpty);

    await drainFileFlowTimers(tester);
  });

  testWidgets('Cancel closes the sheet', (WidgetTester tester) async {
    final FileFlowHost host = await pumpFileFlowHost(tester);

    final AppLocalizations l10n = await openSheet(tester, host);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    expect(find.byType(ImportDialog), findsNothing);
    await drainFileFlowTimers(tester);
  });

  testWidgets('tolerates failing metadata and thumbnails that arrive after closing', (WidgetTester tester) async {
    final String missingPath = pathOf(_missingName);
    final FileFlowHost host = await pumpFileFlowHost(tester);
    await addRecent(tester, host, <String>[missingPath]);
    final Completer<ui.Image?> lateThumbnail = Completer<ui.Image?>();

    showAppBottomSheet<void>(
      context: host.context,
      builder: (BuildContext _) => ImportDialog(
        parentContext: host.context,
        clipboardImageLoader: () async => null,
        recentFileMetadataLoader: (String path, String? bookmark) async => throw StateError(_metadataFailure),
        recentFileThumbnailLoader: (String path, String? bookmark) => lateThumbnail.future,
      ),
    );
    await _pumpSheetTransition(tester);
    final AppLocalizations l10n = AppLocalizations.of(host.context)!;
    expect(find.text(_missingName), findsOneWidget);

    await tester.tap(find.text(l10n.cancel));
    await _pumpSheetTransition(tester);
    expect(find.byType(ImportDialog), findsNothing);

    late ui.Image thumbnail;
    await tester.runAsync(() async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(fileFlowFixtureColor, ui.BlendMode.src);
      thumbnail = await recorder.endRecording().toImage(_clipboardSide, _clipboardSide);
    });
    lateThumbnail.complete(thumbnail);
    await tester.pump();

    expect(thumbnail.debugDisposed, isTrue);
    await drainFileFlowTimers(tester);
  });

  group('clipboard tile', () {
    Future<AppLocalizations> openWithClipboard(WidgetTester tester, FileFlowHost host) async {
      late ui.Image preview;
      await tester.runAsync(() async {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawColor(fileFlowFixtureColor, ui.BlendMode.src);
        preview = await recorder.endRecording().toImage(_clipboardSide, _clipboardSide);
      });
      addTearDown(preview.dispose);
      showAppBottomSheet<void>(
        context: host.context,
        builder: (BuildContext _) => ImportDialog(
          parentContext: host.context,
          clipboardImageLoader: () async => preview,
        ),
      );
      await _pumpSheetTransition(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      final AppLocalizations l10n = AppLocalizations.of(host.context)!;
      expect(find.text(l10n.fromClipboard), findsOneWidget);
      return l10n;
    }

    testWidgets('pastes onto the canvas in add-as-layer mode', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);
      final AppLocalizations l10n = await openWithClipboard(tester, host);
      await enableAddAsLayer(tester, l10n);

      await tester.tap(find.text(l10n.fromClipboard));
      await settleRealAsync(tester);

      expect(find.byType(ImportDialog), findsNothing);
      await drainFileFlowTimers(tester);
    });

    testWidgets('starts a new document from the clipboard otherwise', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);
      final AppLocalizations l10n = await openWithClipboard(tester, host);
      final ui.Size initialSize = host.layers.size;

      await tester.tap(find.text(l10n.fromClipboard));
      await settleRealAsync(tester);

      // The real clipboard is empty in tests, so the guarded flow declines.
      expect(find.byType(ImportDialog), findsNothing);
      expect(host.layers.size, initialSize);
      expect(host.app, isA<AppProvider>());
      await drainFileFlowTimers(tester);
    });
  });
}
