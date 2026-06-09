import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/recent_files_dialog.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/widgets/material_free.dart';

import '../helpers/widget_test_harness.dart';

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

const int _thumbnailPumpAttempts = 20;
const Duration _thumbnailPumpStep = Duration(milliseconds: 50);

Widget _buildHarness({
  required final AppPreferences prefs,
  final Future<ui.Image?> Function()? clipboardImageLoader,
  final RecentFileMetadataLoader? recentFileMetadataLoader,
  final Future<ui.Image?> Function(String path, String? bookmark)? recentFileThumbnailLoader,
}) {
  return ChangeNotifierProvider<AppPreferences>.value(
    value: prefs,
    child: buildLocalizedScaffoldTestApp(
      bodyBuilder: (final BuildContext context) {
        return ImportDialog(
          parentContext: context,
          clipboardImageLoader: clipboardImageLoader,
          recentFileMetadataLoader: recentFileMetadataLoader,
          recentFileThumbnailLoader: recentFileThumbnailLoader,
        );
      },
    ),
  );
}

Future<void> _pumpImportDialog(
  final WidgetTester tester, {
  required final AppPreferences prefs,
  final Future<ui.Image?> Function()? clipboardImageLoader,
  final RecentFileMetadataLoader? recentFileMetadataLoader,
  final Future<ui.Image?> Function(String path, String? bookmark)? recentFileThumbnailLoader,
}) async {
  await tester.pumpWidget(
    _buildHarness(
      prefs: prefs,
      clipboardImageLoader: clipboardImageLoader,
      recentFileMetadataLoader: recentFileMetadataLoader,
      recentFileThumbnailLoader: recentFileThumbnailLoader,
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<ui.Image> _buildClipboardTestImage() {
  return _buildSolidTestImage(
    color: const Color(0xFF4CAF50),
    width: AppLayout.iconSize.toInt(),
    height: AppLayout.iconSize.toInt(),
  );
}

Future<ui.Image> _buildSolidTestImage({
  required final Color color,
  required final int width,
  required final int height,
}) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()..color = color;

  canvas.drawRect(
    Rect.fromLTWH(
      0,
      0,
      width.toDouble(),
      height.toDouble(),
    ),
    paint,
  );

  return recorder.endRecording().toImage(
    width,
    height,
  );
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
        recentFileThumbnailLoader: (final String path, final String? bookmark) async => null,
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
        recentFileThumbnailLoader: (final String path, final String? bookmark) async => null,
      );

      // After async file check fails, thumbnail should switch away from spinner.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text('non_existing_image_c.png'), findsOneWidget);
    });

    testWidgets('renders parent path and modified date for recent files', (final WidgetTester tester) async {
      final String recentFilePath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}fpaint_recent_metadata_${DateTime.now().microsecondsSinceEpoch}.png';
      final File recentFile = File(recentFilePath);
      final DateTime lastModified = DateTime(2024, 5, 6, 13, 24);
      final AppPreferences prefs = _FakePreferences(<String>[recentFile.path]);

      await _pumpImportDialog(
        tester,
        prefs: prefs,
        clipboardImageLoader: () async => null,
        recentFileMetadataLoader: (final String path, final String? bookmark) async => (
          exists: true,
          lastModified: lastModified,
        ),
        recentFileThumbnailLoader: (final String path, final String? bookmark) async => null,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      final BuildContext context = tester.element(find.byType(ImportDialog));
      final MaterialLocalizations materialLocalizations = MaterialLocalizations.of(context);
      final String modifiedLabel =
          '${materialLocalizations.formatShortDate(lastModified)} '
          '${materialLocalizations.formatTimeOfDay(
            TimeOfDay.fromDateTime(lastModified),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          )}';
      final Finder parentPathAppText = find.byWidgetPredicate(
        (final Widget widget) => widget is AppText && widget.data == recentFile.parent.path,
      );
      final Finder modifiedLabelAppText = find.byWidgetPredicate(
        (final Widget widget) => widget is AppText && widget.data == modifiedLabel,
      );

      expect(find.text(recentFile.parent.path), findsOneWidget);
      expect(find.text(modifiedLabel), findsOneWidget);
      expect(parentPathAppText, findsOneWidget);
      expect(modifiedLabelAppText, findsOneWidget);
      expect(tester.widget<AppText>(parentPathAppText).variant, AppTextVariant.subtitle);
      expect(tester.widget<AppText>(modifiedLabelAppText).variant, AppTextVariant.subtitle);
    });

    testWidgets('keeps thumbnails attached to the correct recent files after deletion', (
      final WidgetTester tester,
    ) async {
      final int thumbnailHeight = AppLayout.thumbnailMaxHeight.toInt();
      final List<ui.Image> testThumbnails = <ui.Image>[];
      final String tempPath = Directory.systemTemp.path;

      try {
        final String widePath = '$tempPath${Platform.pathSeparator}wide.png';
        final String tallPath = '$tempPath${Platform.pathSeparator}tall.png';
        final String squarePath = '$tempPath${Platform.pathSeparator}square.png';
        final ui.Image wideThumbnail = await _buildSolidTestImage(
          color: const Color(0xFFE53935),
          width: thumbnailHeight * 2,
          height: thumbnailHeight,
        );
        final ui.Image tallThumbnail = await _buildSolidTestImage(
          color: const Color(0xFF43A047),
          width: thumbnailHeight ~/ 2,
          height: thumbnailHeight,
        );
        final ui.Image squareThumbnail = await _buildSolidTestImage(
          color: const Color(0xFF1E88E5),
          width: thumbnailHeight,
          height: thumbnailHeight,
        );
        testThumbnails.addAll(<ui.Image>[wideThumbnail, tallThumbnail, squareThumbnail]);
        final Map<String, ui.Image> thumbnailsByPath = <String, ui.Image>{
          widePath: wideThumbnail,
          tallPath: tallThumbnail,
          squarePath: squareThumbnail,
        };
        final AppPreferences prefs = _FakePreferences(<String>[
          widePath,
          tallPath,
          squarePath,
        ]);

        await _pumpImportDialog(
          tester,
          prefs: prefs,
          clipboardImageLoader: () async => null,
          recentFileThumbnailLoader: (final String path, final String? bookmark) async => thumbnailsByPath[path],
        );
        await _pumpUntilThumbnailCount(tester, expectedCount: 3);

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
        for (final ui.Image thumbnail in testThumbnails) {
          thumbnail.dispose();
        }
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
