import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';

void main() {
  group('SelectionEffect enum', () {
    test('has 10 values', () {
      expect(SelectionEffect.values.length, 10);
    });

    test('each has an icon', () {
      for (final SelectionEffect effect in SelectionEffect.values) {
        expect(effect.icon, isA<AppIcon>());
      }
    });

    test('blur has the blur icon', () {
      expect(SelectionEffect.blur.icon, AppIcon.effectBlur);
    });

    test('sharpness has the sharpen icon', () {
      expect(SelectionEffect.sharpness.icon, AppIcon.effectSharpen);
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

    test('vignette has the vignette icon', () {
      expect(SelectionEffect.vignette.icon, AppIcon.effectVignette);
    });

    test('only pixelate and noise support size control', () {
      expect(SelectionEffect.pixelate.supportsSizeControl, isTrue);
      expect(SelectionEffect.noise.supportsSizeControl, isTrue);

      for (final SelectionEffect effect in SelectionEffect.values.where(
        (final SelectionEffect effect) => effect != SelectionEffect.pixelate && effect != SelectionEffect.noise,
      )) {
        expect(effect.supportsSizeControl, isFalse);
      }
    });

    test('pixelate and noise expose stable default size values', () {
      expect(SelectionEffect.pixelate.defaultSize, AppEffects.pixelateDefaultSize);
      expect(SelectionEffect.noise.defaultSize, AppEffects.noiseDefaultSize);
    });

    test('pixelate size mapping preserves the authored default and reaches 100', () {
      expect(SelectionEffect.pixelate.sizeValue(SelectionEffect.pixelate.defaultSize), AppEffects.pixelateBlockSize);
      expect(SelectionEffect.pixelate.sizeValue(AppEffects.maxSize), AppEffects.pixelateMaxBlockSize);
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

    test('sharpness returns localized sharpness label', () {
      expect(effectLabel(l10n, SelectionEffect.sharpness), l10n.effectSharpness);
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

    test('vignette returns localized vignette label', () {
      expect(effectLabel(l10n, SelectionEffect.vignette), l10n.effectVignette);
    });
  });

  group('bipolar effects', () {
    test('brightness, contrast and hue are bipolar; others are not', () {
      expect(SelectionEffect.brightness.bipolar, isTrue);
      expect(SelectionEffect.contrast.bipolar, isTrue);
      expect(SelectionEffect.hueSaturation.bipolar, isTrue);
      expect(SelectionEffect.sharpness.bipolar, isTrue);
      expect(SelectionEffect.blur.bipolar, isFalse);
      expect(SelectionEffect.grayscale.bipolar, isFalse);
      expect(SelectionEffect.vignette.bipolar, isFalse);
    });

    test('brightness darkens on negative strength, brightens on positive, no-ops at centre', () async {
      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = const Color(0xFF808080));
      final Image gray = await recorder.endRecording().toImage(4, 4);
      addTearDown(gray.dispose);

      Future<int> redAt(final Image image) async {
        final ByteData data = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
        return data.getUint8(AppMath.rgbChannelRed);
      }

      final Image brighter = await SelectionEffect.brightness.apply(gray, strength: AppEffects.maxIntensity);
      final Image darker = await SelectionEffect.brightness.apply(gray, strength: -AppEffects.maxIntensity);
      final Image centre = await SelectionEffect.brightness.apply(gray, strength: AppEffects.minIntensity);
      addTearDown(brighter.dispose);
      addTearDown(darker.dispose);

      const int mid = 0x80;
      expect(await redAt(brighter), greaterThan(mid));
      expect(await redAt(darker), lessThan(mid));
      // Centre skips the transform and returns the original image untouched.
      expect(await redAt(centre), mid);
    });

    test('sharpness blurs on negative, runs sharpen on positive, no-ops at centre', () async {
      // Vertical hard edge: left half black, right half white (8x8).
      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 4, 8), Paint()..color = const Color(0xFF000000));
      canvas.drawRect(const Rect.fromLTWH(4, 0, 4, 8), Paint()..color = const Color(0xFFFFFFFF));
      final Image edge = await recorder.endRecording().toImage(8, 8);
      addTearDown(edge.dispose);

      final Image centre = await SelectionEffect.sharpness.apply(edge, strength: AppEffects.minIntensity);
      // Centre is a no-op that returns the source image untouched.
      expect(identical(centre, edge), isTrue);

      final Image blurred = await SelectionEffect.sharpness.apply(edge, strength: -AppEffects.maxIntensity);
      final Image sharpened = await SelectionEffect.sharpness.apply(edge, strength: AppEffects.maxIntensity);
      addTearDown(blurred.dispose);
      addTearDown(sharpened.dispose);

      // Negative Sharpness blurs: white bleeds across the edge, so a black-side
      // pixel next to the edge is no longer pure black.
      final ByteData blurredData = (await blurred.toByteData(format: ImageByteFormat.rawRgba))!;
      const int width = 8;
      const int nearEdgeRed = (((4 * width) + 3) * 4) + 0; // pixel (x:3, y:4), red channel
      expect(blurredData.getUint8(nearEdgeRed), greaterThan(0));

      // Positive Sharpness runs the sharpen path (a distinct, non-identity result).
      expect(identical(sharpened, edge), isFalse);
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
