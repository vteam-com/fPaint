import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/effect_intensity_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _previewImageSize = 4;

Future<ui.Image> _createPreviewImage() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _previewImageSize.toDouble(), _previewImageSize.toDouble()),
    Paint()..color = AppColors.white,
  );
  return recorder.endRecording().toImage(_previewImageSize, _previewImageSize);
}

Future<void> _pumpControls(
  final WidgetTester tester, {
  required final AppProvider appProvider,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (final BuildContext context) {
          final AppLocalizations l10n = AppLocalizations.of(context)!;
          return EffectIntensityControls(
            appProvider: appProvider,
            l10n: l10n,
            sliderKey: Keys.effectIntensitySlider,
            applyButtonKey: Keys.effectIntensityPanelApplyButton,
            cancelButtonKey: Keys.effectIntensityCancelButton,
          );
        },
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppProvider appProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
  });

  tearDown(() {
    appProvider.dispose();
  });

  testWidgets('shows size slider for pixelate preview', (final WidgetTester tester) async {
    final ui.Image previewImage = await _createPreviewImage();
    addTearDown(previewImage.dispose);

    appProvider.effectPreviewModel.start(
      selectedEffect: SelectionEffect.pixelate,
      selectionImage: previewImage,
      selectionPath: Path()..addRect(const Rect.fromLTWH(0, 0, 2, 2)),
      selectionBounds: const Rect.fromLTWH(0, 0, 2, 2),
      initialStrength: AppEffects.defaultIntensity,
      initialSize: SelectionEffect.pixelate.defaultSize,
    );

    await _pumpControls(tester, appProvider: appProvider);

    expect(find.byKey(Keys.effectIntensitySlider), findsOneWidget);
    expect(find.byKey(Keys.effectSizeSlider), findsOneWidget);
  });

  testWidgets('shows size slider for noise preview', (final WidgetTester tester) async {
    final ui.Image previewImage = await _createPreviewImage();
    addTearDown(previewImage.dispose);

    appProvider.effectPreviewModel.start(
      selectedEffect: SelectionEffect.noise,
      selectionImage: previewImage,
      selectionPath: Path()..addRect(const Rect.fromLTWH(0, 0, 2, 2)),
      selectionBounds: const Rect.fromLTWH(0, 0, 2, 2),
      initialStrength: AppEffects.defaultIntensity,
      initialSize: SelectionEffect.noise.defaultSize,
    );

    await _pumpControls(tester, appProvider: appProvider);

    expect(find.byKey(Keys.effectIntensitySlider), findsOneWidget);
    expect(find.byKey(Keys.effectSizeSlider), findsOneWidget);
  });

  testWidgets('hides size slider for blur preview', (final WidgetTester tester) async {
    final ui.Image previewImage = await _createPreviewImage();
    addTearDown(previewImage.dispose);

    appProvider.effectPreviewModel.start(
      selectedEffect: SelectionEffect.blur,
      selectionImage: previewImage,
      selectionPath: Path()..addRect(const Rect.fromLTWH(0, 0, 2, 2)),
      selectionBounds: const Rect.fromLTWH(0, 0, 2, 2),
      initialStrength: AppEffects.defaultIntensity,
      initialSize: SelectionEffect.blur.defaultSize,
    );

    await _pumpControls(tester, appProvider: appProvider);

    expect(find.byKey(Keys.effectIntensitySlider), findsOneWidget);
    expect(find.byKey(Keys.effectSizeSlider), findsNothing);
  });
}
