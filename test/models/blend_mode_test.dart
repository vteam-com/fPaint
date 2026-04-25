import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/layers/blend_mode.dart';

void main() {
  group('blendModeToText', () {
    test('srcOver returns Normal without l10n', () {
      expect(blendModeToText(BlendMode.srcOver), 'Normal');
    });

    test('multiply returns Multiply', () {
      expect(blendModeToText(BlendMode.multiply), 'Multiply');
    });

    test('darken returns Darken', () {
      expect(blendModeToText(BlendMode.darken), 'Darken');
    });

    test('lighten returns Lighten', () {
      expect(blendModeToText(BlendMode.lighten), 'Lighten');
    });

    test('screen returns Screen', () {
      expect(blendModeToText(BlendMode.screen), 'Screen');
    });

    test('overlay returns Overlay', () {
      expect(blendModeToText(BlendMode.overlay), 'Overlay');
    });

    test('colorBurn returns ColorBurn capitalized', () {
      expect(blendModeToText(BlendMode.colorBurn), 'ColorBurn');
    });

    test('colorDodge returns ColorDodge capitalized', () {
      expect(blendModeToText(BlendMode.colorDodge), 'ColorDodge');
    });

    test('hue returns Hue', () {
      expect(blendModeToText(BlendMode.hue), 'Hue');
    });

    test('saturation returns Saturation', () {
      expect(blendModeToText(BlendMode.saturation), 'Saturation');
    });

    test('color returns Color', () {
      expect(blendModeToText(BlendMode.color), 'Color');
    });

    test('luminosity returns Luminosity', () {
      expect(blendModeToText(BlendMode.luminosity), 'Luminosity');
    });
  });

  group('getSupportedBlendModes', () {
    testWidgets('returns all 15 blend modes with localized descriptions', (final WidgetTester tester) async {
      late Map<String, Map<String, Object>> modes;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (final BuildContext context) {
              modes = getSupportedBlendModes(context.l10n);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(modes.length, 15);
      expect(modes.containsKey('Normal'), isTrue);
      expect(modes.containsKey('Multiply'), isTrue);
      expect(modes.containsKey('Screen'), isTrue);
      expect(modes.containsKey('Overlay'), isTrue);
      expect(modes.containsKey('Darken'), isTrue);
      expect(modes.containsKey('Lighten'), isTrue);
      expect(modes.containsKey('Hue'), isTrue);
      expect(modes.containsKey('Saturation'), isTrue);
      expect(modes.containsKey('Color'), isTrue);
      expect(modes.containsKey('Luminosity'), isTrue);

      for (final MapEntry<String, Map<String, Object>> entry in modes.entries) {
        expect(
          entry.value.containsKey('flutterBlendMode'),
          isTrue,
          reason: '${entry.key} should have flutterBlendMode',
        );
        expect(entry.value.containsKey('description'), isTrue, reason: '${entry.key} should have description');
        expect(entry.value['flutterBlendMode'], isA<BlendMode>());
        expect(entry.value['description'], isA<String>());
        expect((entry.value['description'] as String).isNotEmpty, isTrue);
      }

      // Normal should map to srcOver
      expect(modes['Normal']!['flutterBlendMode'], BlendMode.srcOver);
    });
  });

  group('blendModeToText with l10n', () {
    testWidgets('srcOver returns localized Normal label', (final WidgetTester tester) async {
      late String result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (final BuildContext context) {
              result = blendModeToText(BlendMode.srcOver, context.l10n);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, isNotEmpty);
    });
  });
}
