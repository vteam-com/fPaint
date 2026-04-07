import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/color_helper.dart';

void main() {
  group('ColorHelper Actual Tests', () {
    group('Brightness', () {
      test('adjustBrightness', () {
        const MaterialColor color = Colors.blue; // L: 0.5 for HSL Blue if pure
        final Color brighter = adjustBrightness(color, 0.8);
        final Color darker = adjustBrightness(color, 0.2);

        expect(HSLColor.fromColor(brighter).lightness, closeTo(0.8, 0.01));
        expect(HSLColor.fromColor(darker).lightness, closeTo(0.2, 0.01));

        final Color same = adjustBrightness(color, HSLColor.fromColor(color).lightness);
        expect(same.toARGB32(), color.toARGB32()); // Should be very close
      });
    });

    group('Hex String Conversions', () {
      test('colorToHexString', () {
        expect(colorToHexString(const Color(0xFF112233)), '#FF112233');
        expect(colorToHexString(const Color(0x80AABBCC), includeAlpha: true, alphaFirst: true), '#80AABBCC');
        expect(colorToHexString(const Color(0x80AABBCC), includeAlpha: true, alphaFirst: false), '#AABBCC80');
        expect(colorToHexString(const Color(0xFFCCDDEE), includeAlpha: false), '#CCDDEE');
        expect(colorToHexString(const Color(0xFF445566), seperator: '-'), '#FF-44-55-66');
      });

      test('getColorComponentsAsHex', () {
        expect(getColorComponentsAsHex(const Color(0xFF123456)), <String>['FF', '12', '34', '56']);
        expect(getColorComponentsAsHex(const Color(0xAB785634), true, false), <String>['78', '56', '34', 'AB']);
        expect(getColorComponentsAsHex(const Color(0xFFCDEEFF), false), <String>['CD', 'EE', 'FF']);
      });

      test('getColorFromString', () {
        expect(getColorFromString('#FF112233'), const Color(0xFF112233));
        expect(getColorFromString('FF112233'), const Color(0xFF112233));
        expect(getColorFromString('#112233'), const Color(0xFF112233)); // Assumes FF alpha
        expect(getColorFromString('112233'), const Color(0xFF112233)); // Assumes FF alpha
        expect(getColorFromString('invalid'), Colors.transparent);
        expect(getColorFromString(''), Colors.transparent);
      });
    });

    group('Color Properties and Conversions', () {
      test('contrastColor', () {
        expect(contrastColor(Colors.black), Colors.white);
        expect(contrastColor(Colors.white), Colors.black);
        expect(contrastColor(Colors.yellow), Colors.black); // Yellow is light
        expect(contrastColor(Colors.blue.shade900), Colors.white); // Dark blue is dark
      });

      test('hsvToColor and adjustBrightness interaction', () {
        // hsvToColor uses adjustBrightness internally.
        // Test if HSV(H, S=1, V=1) with adjustBrightness(V) yields correct color.
        final Color colorFromHsv = hsvToColor(120.0, 0.5); // Hue 120 (Green), Value/Brightness 0.5

        final HSLColor hslColor = HSLColor.fromColor(colorFromHsv);
        // Hue should be preserved
        expect(hslColor.hue, closeTo(120.0, 0.1));
        // Lightness should match the target brightness for V=0.5 (not a direct mapping for S=1)
        // For HSV with S=1, V=0.5, L is 0.25. The hsvToColor uses lightness.
        expect(hslColor.lightness, closeTo(0.5, 0.01));
      });
    });
  });
}
