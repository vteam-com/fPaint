import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/panels/side_panel/recent_files_dialog.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/widgets/material_free.dart';

class _FakePreferences extends AppPreferences {
  _FakePreferences(this._recent);

  final List<String> _recent;
  final Map<String, String> _bookmarks = <String, String>{};

  @override
  bool get isLoaded => true;

  @override
  String? getBookmark(final String path) => _bookmarks[path];

  @override
  List<String> get recentFiles => List<String>.unmodifiable(_recent);

  @override
  Future<void> removeRecentFile(final String path) async {
    _recent.remove(path);
    _bookmarks.remove(path);
    notifyListeners();
  }
}

const int _wideImageWidth = 8;
const int _wideImageHeight = 4;
const int _tallImageWidth = 4;
const int _tallImageHeight = 8;
const int _squareImageSize = 6;
const int _thumbnailPumpAttempts = 20;
const Duration _thumbnailPumpStep = Duration(milliseconds: 50);

Widget _buildHarness({
  required final AppPreferences prefs,
  final Future<ui.Image?> Function()? clipboardImageLoader,
}) {
  return ChangeNotifierProvider<AppPreferences>.value(
    value: prefs,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (final BuildContext context) {
          return Scaffold(
            body: ImportDialog(
              parentContext: context,
              clipboardImageLoader: clipboardImageLoader,
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _pumpImportDialog(
  final WidgetTester tester, {
  required final AppPreferences prefs,
  final Future<ui.Image?> Function()? clipboardImageLoader,
}) async {
  await tester.pumpWidget(
    _buildHarness(
      prefs: prefs,
      clipboardImageLoader: clipboardImageLoader,
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<ui.Image> _buildClipboardTestImage() {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()..color = const Color(0xFF4CAF50);

  canvas.drawRect(
    const Rect.fromLTWH(
      0,
      0,
      AppLayout.iconSize,
      AppLayout.iconSize,
    ),
    paint,
  );

  return recorder.endRecording().toImage(
    AppLayout.iconSize.toInt(),
    AppLayout.iconSize.toInt(),
  );
}

Future<String> _writeTestImage({
  required final Directory directory,
  required final String fileName,
  required final Color color,
  required final int width,
  required final int height,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()..color = color;
  final Rect bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

  canvas.drawRect(bounds, paint);

  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  if (byteData == null) {
    throw StateError('Failed to encode test image.');
  }

  final Uint8List pngBytes = byteData.buffer.asUint8List();
  final File file = File('${directory.path}${Platform.pathSeparator}$fileName');

  await file.writeAsBytes(pngBytes);
  return file.path;
}

Future<void> _pumpUntilThumbnailCount(
  final WidgetTester tester, {
  required final int expectedCount,
}) async {
  for (int attempt = 0; attempt < _thumbnailPumpAttempts; attempt += 1) {
    await tester.pump(_thumbnailPumpStep);
    if (find.byType(RawImage).evaluate().length == expectedCount) {
      return;
    }
  }

  fail('Expected $expectedCount thumbnails to load.');
}

ui.Image _thumbnailForPath(
  final WidgetTester tester, {
  required final String path,
}) {
  final Finder rowFinder = find.byKey(ValueKey<String>(path));
  expect(rowFinder, findsOneWidget);

  final Finder rawImageFinder = find.descendant(
    of: rowFinder,
    matching: find.byType(RawImage),
  );
  expect(rawImageFinder, findsOneWidget);

  final RawImage rawImage = tester.widget<RawImage>(rawImageFinder);
  final ui.Image? image = rawImage.image;

  expect(image, isNotNull);
  return image!;
}

void _expectThumbnailDimensions(
  final WidgetTester tester, {
  required final String path,
  required final int expectedWidth,
  required final int expectedHeight,
}) {
  final ui.Image thumbnail = _thumbnailForPath(tester, path: path);

  expect(thumbnail.width, expectedWidth);
  expect(thumbnail.height, expectedHeight);
}

void main() {
  group('ImportDialog', () {
    testWidgets('renders browse button and recent files list from preferences', (final WidgetTester tester) async {
      final AppPreferences prefs = _FakePreferences(<String>[
        '/tmp/non_existing_image_a.png',
        '/tmp/non_existing_image_b.png',
      ]);

      await _pumpImportDialog(
        tester,
        prefs: prefs,
        clipboardImageLoader: () async => null,
      );

      final BuildContext context = tester.element(find.byType(ImportDialog));
      final AppLocalizations l10n = AppLocalizations.of(context)!;

      expect(find.byType(AppBottomSheetContent), findsOneWidget);
      expect(find.text(l10n.browseFiles), findsOneWidget);
      expect(find.text(l10n.recentFilesLabel), findsOneWidget);
      expect(find.text('non_existing_image_a.png'), findsOneWidget);
      expect(find.text('non_existing_image_b.png'), findsOneWidget);
      expect(find.text(l10n.cancel), findsOneWidget);
    });

    testWidgets('shows loading then fallback thumbnail for missing recent file', (final WidgetTester tester) async {
      final AppPreferences prefs = _FakePreferences(<String>['/tmp/non_existing_image_c.png']);

      await _pumpImportDialog(
        tester,
        prefs: prefs,
        clipboardImageLoader: () async => null,
      );

      // After async file check fails, thumbnail should switch away from spinner.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text('non_existing_image_c.png'), findsOneWidget);
    });

    testWidgets('keeps thumbnails attached to the correct recent files after deletion', (
      final WidgetTester tester,
    ) async {
      final Directory tempDirectory = await Directory.systemTemp.createTemp('fpaint_import_dialog_test_');

      try {
        final String widePath = await _writeTestImage(
          directory: tempDirectory,
          fileName: 'wide.png',
          color: const Color(0xFFE53935),
          width: _wideImageWidth,
          height: _wideImageHeight,
        );
        final String tallPath = await _writeTestImage(
          directory: tempDirectory,
          fileName: 'tall.png',
          color: const Color(0xFF43A047),
          width: _tallImageWidth,
          height: _tallImageHeight,
        );
        final String squarePath = await _writeTestImage(
          directory: tempDirectory,
          fileName: 'square.png',
          color: const Color(0xFF1E88E5),
          width: _squareImageSize,
          height: _squareImageSize,
        );
        final AppPreferences prefs = _FakePreferences(<String>[
          widePath,
          tallPath,
          squarePath,
        ]);

        await _pumpImportDialog(
          tester,
          prefs: prefs,
          clipboardImageLoader: () async => null,
        );
        await _pumpUntilThumbnailCount(tester, expectedCount: 3);

        final int thumbnailHeight = AppLayout.thumbnailMaxHeight.toInt();

        _expectThumbnailDimensions(
          tester,
          path: widePath,
          expectedWidth: thumbnailHeight * 2,
          expectedHeight: thumbnailHeight,
        );
        _expectThumbnailDimensions(
          tester,
          path: tallPath,
          expectedWidth: thumbnailHeight ~/ 2,
          expectedHeight: thumbnailHeight,
        );
        _expectThumbnailDimensions(
          tester,
          path: squarePath,
          expectedWidth: thumbnailHeight,
          expectedHeight: thumbnailHeight,
        );

        final Finder wideRowFinder = find.byKey(ValueKey<String>(widePath));
        final Finder deleteButtonFinder = find.descendant(
          of: wideRowFinder,
          matching: find.byType(AppButton),
        );
        final AppButton deleteButton = tester.widget<AppButton>(deleteButtonFinder);

        deleteButton.onPressed!();
        await tester.pump();

        expect(find.byKey(ValueKey<String>(widePath)), findsNothing);
        expect(find.text('wide.png'), findsNothing);

        _expectThumbnailDimensions(
          tester,
          path: tallPath,
          expectedWidth: thumbnailHeight ~/ 2,
          expectedHeight: thumbnailHeight,
        );
        _expectThumbnailDimensions(
          tester,
          path: squarePath,
          expectedWidth: thumbnailHeight,
          expectedHeight: thumbnailHeight,
        );
      } finally {
        await tempDirectory.delete(recursive: true);
      }
    });

    testWidgets('add as layer switch toggles in dialog state', (final WidgetTester tester) async {
      final AppPreferences prefs = _FakePreferences(<String>[]);

      await _pumpImportDialog(
        tester,
        prefs: prefs,
        clipboardImageLoader: () async => null,
      );

      final BuildContext context = tester.element(find.byType(ImportDialog));
      final AppLocalizations l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.addAsNewLayer), findsOneWidget);

      await tester.tap(find.text(l10n.addAsNewLayer));
      await tester.pump();

      // Label remains present and dialog state updates without errors.
      expect(find.text(l10n.addAsNewLayer), findsOneWidget);
    });

    testWidgets('shows clipboard tile when an image is available', (final WidgetTester tester) async {
      final AppPreferences prefs = _FakePreferences(<String>[]);
      final ui.Image clipboardImage = await _buildClipboardTestImage();

      await _pumpImportDialog(
        tester,
        prefs: prefs,
        clipboardImageLoader: () async => clipboardImage,
      );

      final BuildContext context = tester.element(find.byType(ImportDialog));
      final AppLocalizations l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.fromClipboard), findsOneWidget);
    });
  });
}
