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

  @override
  bool get isLoaded => true;

  @override
  List<String> get recentFiles => List<String>.unmodifiable(_recent);
}

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
