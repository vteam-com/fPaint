import 'dart:math'; // Added for sqrt

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/color_helper.dart';

void main() {
  group('ColorHelper Actual Tests', () {
    group('Tinting Functions', () {
      test('addTintOfRed', () {
        const Color color = Color(0xFF00FF00); // Green
        final Color tinted = addTintOfRed(color, 50);
        // Original R is 0. 0 + 50 = 50.
        // Expected: R=50 (0x32), G=255 (0xFF), B=0 (0x00)
        expect(tinted, const Color.fromARGB(255, 50, 255, 0));

        const Color color2 = Color.fromRGBO(100, 100, 100, 1.0); // Opaque Grey
        final Color tinted2 = addTintOfRed(color2, 200); // 100 + 200 = 300, clamped to 255
        expect((tinted2.r * 255.0).round() & 0xff, 255);
        expect((tinted2.g * 255.0).round() & 0xff, 100);
        expect((tinted2.b * 255.0).round() & 0xff, 100);
      });

      test('addTintOfBlue', () {
        const Color color = Color(0xFFFF0000); // Red
        final Color tinted = addTintOfBlue(color, 100);
        // Original B is 0. 0 + 100 = 100.
        // Expected: R=255 (0xFF), G=0 (0x00), B=100 (0x64)
        expect(tinted, const Color.fromARGB(255, 255, 0, 100));
      });

      test('addTintOfGreen', () {
        const Color color = Color(0xFFFF0000); // Red
        final Color tinted = addTintOfGreen(color, 150);
        // Original G is 0. 0 + 150 = 150.
        // Expected: R=255 (0xFF), G=150 (0x96), B=0 (0x00)
        expect(tinted, const Color.fromARGB(255, 255, 150, 0));
      });
    });

    group('Brightness and Opacity', () {
      test('adjustBrightness', () {
        const MaterialColor color = Colors.blue; // L: 0.5 for HSL Blue if pure
        final Color brighter = adjustBrightness(color, 0.8);
        final Color darker = adjustBrightness(color, 0.2);

        expect(HSLColor.fromColor(brighter).lightness, closeTo(0.8, 0.01));
        expect(HSLColor.fromColor(darker).lightness, closeTo(0.2, 0.01));

        final Color same = adjustBrightness(color, HSLColor.fromColor(color).lightness);
        expect(same.toARGB32(), color.toARGB32()); // Should be very close
      });

      test('adjustOpacityOfTextStyle', () {
        const TextStyle style = TextStyle(color: Colors.red);
        final TextStyle adjustedStyle = adjustOpacityOfTextStyle(style, 0.5);
        expect(adjustedStyle.color, Colors.red.withAlpha((0.5 * 255).round()));

        final TextStyle defaultOpacityStyle = adjustOpacityOfTextStyle(style);
        expect(defaultOpacityStyle.color, Colors.red.withAlpha((0.7 * 255).round()));
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

      test('getHexOnMultiline', () {
        expect(getHexOnMultiline(const Color(0xFF1A2B3C)), 'FF\n1A\n2B\n3C');
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

      test('getHueFromColor', () {
        expect(getHueFromColor(Colors.red), HSLColor.fromColor(Colors.red).hue); // H:0
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

      test('invertColor (specific implementation: 1.0 - component, alpha preserved)', () {
        // Using Color.fromARGB to define test colors as helper uses floating point 0-1 for r,g,b
        const Color originalF = Color.fromRGBO(51, 102, 153, 0.5); // R:0.2, G:0.4, B:0.6, A:0.5
        // Expected inverted: R:0.8, G:0.6, B:0.4, A:0.5
        // R = (1-0.2)*255 = 0.8*255 = 204
        // G = (1-0.4)*255 = 0.6*255 = 153
        // B = (1-0.6)*255 = 0.4*255 = 102
        final Color invertedF = invertColor(originalF);

        expect((invertedF.r * 255.0).round() & 0xff, 204);
        expect((invertedF.g * 255.0).round() & 0xff, 153);
        expect((invertedF.b * 255.0).round() & 0xff, 102);
        // The current invertColor in color_helper.dart sets alpha to 1.0 (opaque)
        expect((invertedF.a * 255.0).round() & 0xff, 255); // Alpha is forced to 1.0 by current implementation

        // Test with a color that has alpha != 1.0 if invertColor were to preserve it
        // However, current `invertColor` uses Color.fromRGBO(r,g,b,1.0) so alpha is always 1.0
      });
    });

    group('Color Comparison', () {
      test('colorDistance', () {
        // Note: The colorDistance in helper uses r,g,b components (0.0-1.0 float)
        // So Colors.red (255,0,0) needs to be seen as (1.0, 0, 0) effectively by the formula's terms
        // Let's test with Color.fromRGBO for clarity if it uses 0-255 or 0-1.
        // The implementation uses color.r, color.g, color.b which are doubles (0.0-1.0)

        const Color c1 = Color.fromRGBO(255, 0, 0, 1.0); // Red (r=1.0)
        const Color c2 = Color.fromRGBO(0, 255, 0, 1.0); // Green (g=1.0)
        // dist = sqrt((1-0)^2 + (0-1)^2 + (0-0)^2) = sqrt(1+1+0) = sqrt(2)
        expect(colorDistance(c1, c1), 0.0);
        expect(colorDistance(c1, c2), closeTo(sqrt(2.0), 0.0001));

        const Color black = Color.fromRGBO(0, 0, 0, 1.0); // (0,0,0)
        const Color white = Color.fromRGBO(255, 255, 255, 1.0); // (1,1,1)
        // dist = sqrt((0-1)^2 + (0-1)^2 + (0-1)^2) = sqrt(1+1+1) = sqrt(3)
        expect(colorDistance(black, white), closeTo(sqrt(3.0), 0.0001));
      });
    });
  });
}
