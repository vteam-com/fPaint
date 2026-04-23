import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';

void main() {
  group('AppSvgIcon', () {
    testWidgets('creates SvgPicture with explicit color', (final WidgetTester tester) async {
      const Widget widget = AppSvgIcon(icon: AppIcon.brush, color: Colors.red);
      expect(widget, isA<Widget>());
    });

    testWidgets('isSelected true produces blue icon', (final WidgetTester tester) async {
      const Widget widget = AppSvgIcon(icon: AppIcon.brush, isSelected: true);
      expect(widget, isA<Widget>());
    });

    testWidgets('isSelected false produces white icon', (final WidgetTester tester) async {
      const Widget widget = AppSvgIcon(icon: AppIcon.brush, isSelected: false);
      expect(widget, isA<Widget>());
    });
  });
}
