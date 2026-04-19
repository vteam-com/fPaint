// ignore_for_file: unnecessary_import

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/color_helper.dart' hide hsvToColor;
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  group('ColorSelector Widget Tests', () {
    testWidgets('Initial rendering reflects input color', (final WidgetTester tester) async {
      // Using blue as it has a non-zero hue, to avoid potential issues with hue=0 being default/uninitialized for slider
      const Color initialColor = Color.fromARGB(255, 0, 0, 255); // Blue

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorSelector(
              color: initialColor,
              onColorChanged: (final Color color) {
                //
              },
            ),
          ),
        ),
      );

      // Find sliders (there are 3: Hue, Brightness, Alpha)
      final Finder sliders = find.byType(Slider);
      expect(sliders, findsNWidgets(3));

      // Verify slider positions based on initialColor (Red: H=0, S=1, V=1 or L=0.5 for HSL)
      // The ColorSelector uses a custom HSL-like model where brightness is L.
      // Red: H=0, L=0.5, A=1.0
      final HSLColor hslColor = HSLColor.fromColor(initialColor);

      final Slider hueSlider = tester.widget(sliders.at(0));
      expect(hueSlider.value, closeTo(hslColor.hue, 0.1));

      final Slider brightnessSlider = tester.widget(sliders.at(1));
      expect(brightnessSlider.value, closeTo(hslColor.lightness, 0.01));

      final Slider alphaSlider = tester.widget(sliders.at(2));
      expect(alphaSlider.value, closeTo(hslColor.alpha, 0.01));
    });

    testWidgets('Hue slider interaction calls onColorChanged and updates color', (final WidgetTester tester) async {
      Color currentColor = const Color.fromARGB(255, 255, 0, 0); // Initial Red
      Color? newColorReported;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (final BuildContext context, final StateSetter setState) {
            return MaterialApp(
              home: Scaffold(
                body: ColorSelector(
                  color: currentColor,
                  onColorChanged: (final Color color) {
                    setState(() {
                      newColorReported = color;
                      currentColor = color; // Keep widget updated if it rebuilds with new color
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      final Finder sliders = find.byType(Slider);
      expect(sliders, findsNWidgets(3));

      // Change Hue to 120 (Green)
      await tester.drag(sliders.at(0), const Offset(100.0, 0.0)); // Simulate a drag, precise value is hard
      await tester.pumpAndSettle(); // Let slider animation finish

      // For more precise value setting:
      final Finder hueSliderFinder = sliders.at(0);
      final Slider hueSliderWidget = tester.widget(hueSliderFinder);
      final double targetHue = 120.0;
      // Call onChanged directly, as drag is imprecise for exact value verification
      hueSliderWidget.onChanged!(targetHue);
      await tester.pumpAndSettle();

      expect(newColorReported, isNotNull);
      final HSLColor hslNewColor = HSLColor.fromColor(newColorReported!);
      expect(hslNewColor.hue, closeTo(targetHue, 0.5)); // Hue should be approx 120
      // Default S is 1.0, L is 0.5 if not black/white for the hue slider logic
      // Check if brightness was reset to 0.5 if it was 0 or 1
      final HSLColor initialHsl = HSLColor.fromColor(const Color.fromARGB(255, 255, 0, 0));
      if (initialHsl.lightness == 0.0 || initialHsl.lightness == 1.0) {
        expect(hslNewColor.lightness, closeTo(0.5, 0.01));
      } else {
        expect(hslNewColor.lightness, closeTo(initialHsl.lightness, 0.01));
      }
      expect(hslNewColor.alpha, closeTo(initialHsl.alpha, 0.01));
    });

    testWidgets('Brightness slider interaction calls onColorChanged', (final WidgetTester tester) async {
      final Color currentColor = const Color.fromARGB(255, 255, 0, 0); // Initial Red
      Color? newColorReported;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorSelector(
              color: currentColor,
              onColorChanged: (final Color color) {
                newColorReported = color;
              },
            ),
          ),
        ),
      );

      final Finder brightnessSliderFinder = find.byType(Slider).at(1);
      final Slider brightnessSliderWidget = tester.widget(brightnessSliderFinder);
      brightnessSliderWidget.onChanged!(0.8); // Change brightness
      await tester.pumpAndSettle();

      expect(newColorReported, isNotNull);
      expect(HSLColor.fromColor(newColorReported!).lightness, closeTo(0.8, 0.01));
    });

    testWidgets('Alpha slider interaction calls onColorChanged', (final WidgetTester tester) async {
      final Color currentColor = const Color.fromARGB(255, 255, 0, 0); // Initial Red
      Color? newColorReported;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorSelector(
              color: currentColor,
              onColorChanged: (final Color color) {
                newColorReported = color;
              },
            ),
          ),
        ),
      );

      final Finder alphaSliderFinder = find.byType(Slider).at(2);
      final Slider alphaSliderWidget = tester.widget(alphaSliderFinder);
      alphaSliderWidget.onChanged!(0.5); // Change alpha
      await tester.pumpAndSettle();

      expect(newColorReported, isNotNull);
      expect((newColorReported!.a * 255.0).round(), closeTo((0.5 * 255).round(), 1)); // Alpha is 0-255
    });

    testWidgets(
      'didUpdateWidget updates internal HSV and Alpha state',
      (final WidgetTester tester) async {
        Color testColor = Colors.cyan; // Start with Cyan (H=180)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ColorSelector(
                color: testColor,
                onColorChanged: (final Color color) {},
              ),
            ),
          ),
        );

        // Verify initial slider state for Colors.cyan.
        Finder sliders = find.byType(Slider);
        final HSLColor initialCyanHsl = HSLColor.fromColor(Colors.cyan); // Actual HSL for Colors.cyan
        Slider hueSliderWidget = tester.widget(sliders.at(0));
        expect(hueSliderWidget.value, closeTo(initialCyanHsl.hue, 0.1));
        expect(tester.widget<Slider>(sliders.at(1)).value, closeTo(initialCyanHsl.lightness, 0.01));
        expect(tester.widget<Slider>(sliders.at(2)).value, closeTo(Colors.cyan.a, 0.01));

        // Change color property and rebuild to Orange
        testColor = Colors.orange; // Orange: H~30-38, L~0.5, A=1.0
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ColorSelector(
                color: testColor,
                onColorChanged: (final Color color) {},
              ),
            ),
          ),
        );

        sliders = find.byType(Slider);
        final HSLColor orangeHsl = HSLColor.fromColor(Colors.orange);
        // Verify state for Colors.orange.
        hueSliderWidget = tester.widget(sliders.at(0)); // Re-fetch slider
        expect(hueSliderWidget.value, closeTo(orangeHsl.hue, 0.1));
        expect(tester.widget<Slider>(sliders.at(1)).value, closeTo(orangeHsl.lightness, 0.01));
        expect(tester.widget<Slider>(sliders.at(2)).value, closeTo(Colors.orange.a, 0.01));
      },
      // Re-enabled: verify hue/init update behavior directly.
    );
  });

  group('CustomPainters Tests', () {
    testWidgets('HueGradientPainter shouldRepaint is false', (final WidgetTester tester) async {
      final HueGradientPainter painter = HueGradientPainter();
      expect(painter.shouldRepaint(HueGradientPainter()), isFalse);
    });

    testWidgets('BrightnessGradientPainter shouldRepaint based on hue', (final WidgetTester tester) async {
      final BrightnessGradientPainter painter1 = BrightnessGradientPainter(hue: 0);
      final BrightnessGradientPainter painter2 = BrightnessGradientPainter(hue: 0);
      final BrightnessGradientPainter painter3 = BrightnessGradientPainter(hue: 120);
      expect(painter1.shouldRepaint(painter2), isFalse); // Same hue
      expect(painter1.shouldRepaint(painter3), isTrue); // Different hue
    });

    testWidgets('AlphaGradientPainter shouldRepaint based on hue or brightness', (final WidgetTester tester) async {
      final AlphaGradientPainter painter1 = AlphaGradientPainter(hue: 0, brightness: 0.5);
      final AlphaGradientPainter painter2 = AlphaGradientPainter(hue: 0, brightness: 0.5); // Same as painter1
      final AlphaGradientPainter painter3 = AlphaGradientPainter(hue: 120, brightness: 0.5); // Different hue
      final AlphaGradientPainter painter4 = AlphaGradientPainter(hue: 0, brightness: 0.8); // Different brightness

      expect(painter1.shouldRepaint(painter2), isFalse); // Same properties
      expect(painter1.shouldRepaint(painter3), isTrue); // Different hue
      expect(painter1.shouldRepaint(painter4), isTrue); // Different brightness
    });
  });

  group('showColorPicker Utility', () {
    testWidgets(
      'showColorPicker calls showDialog with ColorPickerDialog',
      (final WidgetTester tester) async {
        Color selectedColorOut = Colors.transparent;
        final ShellProvider shellProvider = ShellProvider()..deviceSizeSmall = false;
        final LayersProvider layersProvider = LayersProvider()..topColors = <ColorUsage>[];

        // Set a larger physical size for the test window to avoid overflow
        final Size originalSize = tester.view.physicalSize; // Correct way to get size
        final double originalPixelRatio = tester.view.devicePixelRatio;
        tester.view.physicalSize = const Size(1200 * 3.0, 1200 * 3.0); // Set physical pixels
        tester.view.devicePixelRatio = 3.0; // Set device pixel ratio
        addTearDown(() {
          tester.view.physicalSize = originalSize;
          tester.view.devicePixelRatio = originalPixelRatio;
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: <SingleChildWidget>[
              ChangeNotifierProvider<ShellProvider>.value(value: shellProvider),
              ChangeNotifierProvider<LayersProvider>.value(value: layersProvider),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              // Added ThemeData
              theme: ThemeData(),
              home: Scaffold(
                body: Builder(
                  builder: (final BuildContext context) {
                    return ElevatedButton(
                      onPressed: () {
                        showColorPicker(
                          context: context,
                          title: 'Test Picker',
                          color: Colors.red, // Initial color for the dialog's ColorSelector
                          onSelectedColor: (final Color color) {
                            selectedColorOut = color;
                          },
                        );
                      },
                      child: const Text('Show Picker'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Picker'));
        await tester.pumpAndSettle(); // Allow dialog to show

        // Check if ColorPickerDialog is shown
        expect(find.byType(ColorPickerDialog), findsOneWidget);
        expect(find.text('Test Picker'), findsOneWidget);

        // Simulate selecting a color by interacting with the ColorSelector's slider inside the dialog
        final Finder sliderInDialogFinder = find.descendant(
          of: find.byType(ColorPickerDialog),
          matching: find.byType(Slider),
        );
        expect(sliderInDialogFinder, findsNWidgets(3)); // Hue, Brightness, Alpha sliders

        final Slider hueSliderInDialog = tester.widget(sliderInDialogFinder.at(0));

        // Simulate changing hue to 120.0 (Greenish) while preserving lightness/alpha from input color.
        final HSLColor initialHsl = HSLColor.fromColor(Colors.red);
        final Color expectedSelectedColor = HSLColor.fromAHSL(
          Colors.red.a,
          120.0,
          1.0,
          initialHsl.lightness,
        ).toColor();

        hueSliderInDialog.onChanged!(120.0);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        expect(selectedColorOut.toARGB32(), expectedSelectedColor.toARGB32());
        expect(find.byType(ColorPickerDialog), findsNothing);
      },
      // Re-enabled: verify dialog callback flow end-to-end.
    );
  });

  group('hsvToColor Utility (local to color_selector.dart)', () {
    test('hsvToColor converts correctly', () {
      // Red: H=0, S=1, V=1 (L=0.5 in HSL if S=1) -> Alpha=1
      expect(hsvToColor(0, 0.5, 1.0), const Color.fromARGB(255, 255, 0, 0));
      // Green: H=120, S=1, V=1 (L=0.5) -> Alpha=1
      expect(hsvToColor(120, 0.5, 1.0), const Color.fromARGB(255, 0, 255, 0));
      // Blue: H=240, S=1, V=1 (L=0.5) -> Alpha=1
      expect(hsvToColor(240, 0.5, 1.0), const Color.fromARGB(255, 0, 0, 255));
      // If we want grey, brightness (Lightness) should be 0.5, and Hue doesn't matter if Saturation was 0.
      // But the function uses Saturation = 1.0.
      // Let's test a known grey: H=0, S=0, L=0.5
      expect(const HSLColor.fromAHSL(1.0, 0, 0.0, 0.5).toColor(), const Color.fromARGB(255, 128, 128, 128));
    });
  });
}
