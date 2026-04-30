import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';

void main() {
  group('SelectionEffect enum', () {
    test('has 11 values', () {
      expect(SelectionEffect.values.length, 11);
    });

    test('each has an icon', () {
      for (final SelectionEffect effect in SelectionEffect.values) {
        expect(effect.icon, isA<AppIcon>());
      }
    });

    test('blur has the blur icon', () {
      expect(SelectionEffect.blur.icon, AppIcon.effectBlur);
    });

    test('sharpen has the sharpen icon', () {
      expect(SelectionEffect.sharpen.icon, AppIcon.effectSharpen);
    });

    test('pixelate has the pixelate icon', () {
      expect(SelectionEffect.pixelate.icon, AppIcon.effectPixelate);
    });

    test('grayscale has the grayscale icon', () {
      expect(SelectionEffect.grayscale.icon, AppIcon.effectGrayscale);
    });

    test('noise has the noise icon', () {
      expect(SelectionEffect.noise.icon, AppIcon.effectNoise);
    });

    test('soften has the soften icon', () {
      expect(SelectionEffect.soften.icon, AppIcon.effectSoften);
    });

    test('vignette has the vignette icon', () {
      expect(SelectionEffect.vignette.icon, AppIcon.effectVignette);
    });
  });

  group('effectLabel', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('returns non-empty label for every effect', () {
      for (final SelectionEffect effect in SelectionEffect.values) {
        final String label = effectLabel(l10n, effect);
        expect(label.isNotEmpty, isTrue, reason: '${effect.name} has empty label');
      }
    });

    test('blur returns localized blur label', () {
      expect(effectLabel(l10n, SelectionEffect.blur), l10n.effectBlur);
    });

    test('sharpen returns localized sharpen label', () {
      expect(effectLabel(l10n, SelectionEffect.sharpen), l10n.effectSharpen);
    });

    test('pixelate returns localized pixelate label', () {
      expect(effectLabel(l10n, SelectionEffect.pixelate), l10n.effectPixelate);
    });

    test('grayscale returns localized grayscale label', () {
      expect(effectLabel(l10n, SelectionEffect.grayscale), l10n.effectGrayscale);
    });

    test('noise returns localized noise label', () {
      expect(effectLabel(l10n, SelectionEffect.noise), l10n.effectNoise);
    });

    test('soften returns localized soften label', () {
      expect(effectLabel(l10n, SelectionEffect.soften), l10n.effectSoften);
    });

    test('vignette returns localized vignette label', () {
      expect(effectLabel(l10n, SelectionEffect.vignette), l10n.effectVignette);
    });
  });

  group('SelectionEffect.apply', () {
    test('each effect can apply to a small image', () async {
      // Create a small test image
      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 10, 10),
        Paint()..color = const Color(0xFFFF0000),
      );
      final Image sourceImage = await recorder.endRecording().toImage(10, 10);

      for (final SelectionEffect effect in SelectionEffect.values) {
        final Image result = await effect.apply(sourceImage);
        expect(result.width, greaterThan(0), reason: '${effect.name} produced invalid image');
        expect(result.height, greaterThan(0), reason: '${effect.name} produced invalid image');
      }
    });
  });
}
