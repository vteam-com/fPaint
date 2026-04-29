import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/layers/blend_mode.dart';
import 'package:fpaint/widgets/material_free.dart';

void main() {
  group('getSupportedBlendModes', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('returns 15 blend modes', () {
      final Map<String, Map<String, Object>> modes = getSupportedBlendModes(l10n);
      expect(modes.length, 15);
    });

    test('contains Normal as first entry', () {
      final Map<String, Map<String, Object>> modes = getSupportedBlendModes(l10n);
      expect(modes.keys.first, 'Normal');
    });

    test('all entries have flutterBlendMode key', () {
      final Map<String, Map<String, Object>> modes = getSupportedBlendModes(l10n);
      for (final MapEntry<String, Map<String, Object>> entry in modes.entries) {
        expect(
          entry.value.containsKey('flutterBlendMode'),
          isTrue,
          reason: '${entry.key} missing flutterBlendMode',
        );
        expect(entry.value['flutterBlendMode'], isA<BlendMode>());
      }
    });

    test('all entries have description key', () {
      final Map<String, Map<String, Object>> modes = getSupportedBlendModes(l10n);
      for (final MapEntry<String, Map<String, Object>> entry in modes.entries) {
        expect(
          entry.value.containsKey('description'),
          isTrue,
          reason: '${entry.key} missing description',
        );
        expect(entry.value['description'], isA<String>());
        expect(
          (entry.value['description'] as String).isNotEmpty,
          isTrue,
          reason: '${entry.key} has empty description',
        );
      }
    });

    test('Normal maps to BlendMode.srcOver', () {
      final Map<String, Map<String, Object>> modes = getSupportedBlendModes(l10n);
      expect(modes['Normal']!['flutterBlendMode'], BlendMode.srcOver);
    });

    test('Multiply maps to BlendMode.multiply', () {
      final Map<String, Map<String, Object>> modes = getSupportedBlendModes(l10n);
      expect(modes['Multiply']!['flutterBlendMode'], BlendMode.multiply);
    });

    test('Screen maps to BlendMode.screen', () {
      final Map<String, Map<String, Object>> modes = getSupportedBlendModes(l10n);
      expect(modes['Screen']!['flutterBlendMode'], BlendMode.screen);
    });

    test('Overlay maps to BlendMode.overlay', () {
      final Map<String, Map<String, Object>> modes = getSupportedBlendModes(l10n);
      expect(modes['Overlay']!['flutterBlendMode'], BlendMode.overlay);
    });

    test('contains all expected blend mode names', () {
      final Map<String, Map<String, Object>> modes = getSupportedBlendModes(l10n);
      final List<String> expectedNames = <String>[
        'Normal',
        'Darken',
        'Multiply',
        'Color Burn',
        'Lighten',
        'Screen',
        'Color Dodge',
        'Linear Dodge (Add)',
        'Overlay',
        'Soft Light',
        'Hard Light',
        'Hue',
        'Saturation',
        'Color',
        'Luminosity',
      ];
      for (final String name in expectedNames) {
        expect(modes.containsKey(name), isTrue, reason: 'Missing blend mode: $name');
      }
    });
  });

  group('blendModeToText', () {
    test('returns Normal for srcOver', () {
      expect(blendModeToText(BlendMode.srcOver), 'Normal');
    });

    test('returns localized Normal for srcOver with l10n', () async {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final String result = blendModeToText(BlendMode.srcOver, l10n);
      expect(result.isNotEmpty, isTrue);
    });

    test('capitalizes other blend mode names', () {
      expect(blendModeToText(BlendMode.multiply), 'Multiply');
      expect(blendModeToText(BlendMode.screen), 'Screen');
      expect(blendModeToText(BlendMode.overlay), 'Overlay');
      expect(blendModeToText(BlendMode.darken), 'Darken');
      expect(blendModeToText(BlendMode.lighten), 'Lighten');
    });

    test('handles blend modes with multi-word names', () {
      // These will just capitalize the first letter of the enum name
      final String result = blendModeToText(BlendMode.colorBurn);
      expect(result[0], result[0].toUpperCase());
      expect(result.isNotEmpty, isTrue);
    });
  });

  group('showBlendModeMenu widget test', () {
    testWidgets('shows and selects blend mode', (final WidgetTester tester) async {
      BlendMode? selectedMode;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) {
                return GestureDetector(
                  onTap: () async {
                    selectedMode = await showBlendModeMenu(
                      context: context,
                      position: const Offset(100, 100),
                      selectedBlendMode: BlendMode.srcOver,
                    );
                  },
                  child: const AppText('Trigger'),
                );
              },
            ),
          ),
        ),
      );

      // Tap to trigger the menu.
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      // Menu should show blend mode entries.
      expect(find.text('Normal'), findsWidgets);
      expect(find.text('Multiply'), findsWidgets);

      // Tap on Multiply.
      await tester.tap(find.text('Multiply').last);
      await tester.pumpAndSettle();

      expect(selectedMode, BlendMode.multiply);
    });

    testWidgets('returns srcOver when cancelled', (final WidgetTester tester) async {
      BlendMode? selectedMode;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) {
                return GestureDetector(
                  onTap: () async {
                    selectedMode = await showBlendModeMenu(
                      context: context,
                      position: const Offset(100, 100),
                    );
                  },
                  child: const AppText('Trigger'),
                );
              },
            ),
          ),
        ),
      );

      // Tap to trigger.
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      // Dismiss by tapping outside (press Escape).
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(selectedMode, BlendMode.srcOver);
    });
  });
}
