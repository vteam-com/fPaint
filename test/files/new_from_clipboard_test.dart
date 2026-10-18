import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:material_ui/material_ui.dart';

const Size _initialCanvasSize = Size(800, 600);
const int _clipboardWidth = 32;
const int _clipboardHeight = 24;

/// Regression tests for the unified "New from clipboard" entry point: every
/// caller must confirm discarding unsaved work and fit the new canvas.
void main() {
  late UndoProvider undo;
  late LayersProvider layers;
  late AppProvider app;
  late ShellProvider shell;
  late BuildContext hostContext;
  late int fitRequests;

  Future<void> seedClipboardImage(WidgetTester tester) async {
    await tester.runAsync(() async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        Rect.fromLTWH(0, 0, _clipboardWidth.toDouble(), _clipboardHeight.toDouble()),
        Paint()..color = const Color(0xFF00FF00),
      );
      final ui.Image image = await recorder.endRecording().toImage(_clipboardWidth, _clipboardHeight);
      final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await copyImageBytesToClipboard(png!.buffer.asUint8List());
    });
  }

  Future<void> pumpHost(WidgetTester tester, {required bool hasChanges}) async {
    undo = UndoProvider();
    layers = LayersProvider(undoProvider: undo)..size = _initialCanvasSize;
    app = AppProvider(
      preferences: AppPreferences(),
      layersProvider: layers,
    );
    shell = ShellProvider();
    fitRequests = 0;
    shell.canvasFitRequestListenable.addListener(() => fitRequests++);
    if (hasChanges) {
      layers.markAllChanged();
    } else {
      layers.clearHasChanged();
    }
    addTearDown(() {
      app.dispose();
      layers.dispose();
      undo.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              hostContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  /// Lets the layers' debounced thumbnail rebuilds fire so no timer outlives
  /// the test.
  Future<void> drainThumbnailTimers(WidgetTester tester) async {
    await tester.pump(AppDefaults.thumbnailDebounceDuration);
    await tester.pumpAndSettle();
  }

  Future<bool> runGuarded(WidgetTester tester, {String? answer}) async {
    final Future<bool> result = newDocumentFromClipboardGuarded(
      hostContext,
      appProvider: app,
      shellProvider: shell,
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    if (answer != null) {
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
    }
    bool? created;
    await tester.runAsync(() async {
      created = await result;
    });
    await tester.pumpAndSettle();
    return created!;
  }

  testWidgets('declining the discard prompt keeps the current document', (WidgetTester tester) async {
    await seedClipboardImage(tester);
    await pumpHost(tester, hasChanges: true);

    final bool created = await runGuarded(tester, answer: 'No');

    expect(created, isFalse);
    expect(layers.size, _initialCanvasSize);
    expect(fitRequests, 0);
    await drainThumbnailTimers(tester);
  });

  testWidgets('confirming discard creates the document and fits it', (WidgetTester tester) async {
    await seedClipboardImage(tester);
    await pumpHost(tester, hasChanges: true);

    final bool created = await runGuarded(tester, answer: 'Discard');

    expect(created, isTrue);
    expect(layers.size, Size(_clipboardWidth.toDouble(), _clipboardHeight.toDouble()));
    expect(fitRequests, greaterThan(0));
    await drainThumbnailTimers(tester);
  });

  testWidgets('unchanged documents are replaced without a prompt', (WidgetTester tester) async {
    await seedClipboardImage(tester);
    await pumpHost(tester, hasChanges: false);

    final bool created = await runGuarded(tester);

    expect(find.text('Discard'), findsNothing);
    expect(created, isTrue);
    expect(layers.size, Size(_clipboardWidth.toDouble(), _clipboardHeight.toDouble()));
    expect(fitRequests, greaterThan(0));
    await drainThumbnailTimers(tester);
  });
}
