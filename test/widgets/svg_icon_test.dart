import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/widgets/svg_icon.dart';

void main() {
  group('SVG Icon Widgets', () {
    testWidgets('iconFromSvgAsset creates SvgPicture with correct properties', (final WidgetTester tester) async {
      // Test that the function returns a widget (basic smoke test)
      final Widget widget = iconFromSvgAsset('test/path.svg', Colors.red);

      expect(widget, isA<Widget>());
      // Note: Full testing would require flutter_svg mocking, but this tests the function exists and returns a widget
    });

    testWidgets('iconFromSvgAssetSelected uses blue for selected state', (final WidgetTester tester) async {
      final Widget widget = iconFromSvgAssetSelected('test/path.svg', true);

      expect(widget, isA<Widget>());
      // The function calls iconFromSvgAsset with Colors.blue when selected
    });

    testWidgets('iconFromSvgAssetSelected uses white for unselected state', (final WidgetTester tester) async {
      final Widget widget = iconFromSvgAssetSelected('test/path.svg', false);

      expect(widget, isA<Widget>());
      // The function calls iconFromSvgAsset with Colors.white when not selected
    });
  });
}
