import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';

const double _renderedIconSize = AppLayout.layerPreviewSize;

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

    testWidgets('preserves the provided color alpha when tinting svg assets', (final WidgetTester tester) async {
      final Color semiTransparentRed = AppColors.red.withAlpha(AppLayout.overlayAlpha);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.square(
            dimension: _renderedIconSize,
            child: AppSvgIcon(
              icon: AppIcon.waterDrop,
              color: semiTransparentRed,
              size: _renderedIconSize,
            ),
          ),
        ),
      );

      final SvgPicture picture = tester.widget<SvgPicture>(find.byType(SvgPicture));

      expect(
        picture.colorFilter.toString(),
        ColorFilter.mode(semiTransparentRed, BlendMode.srcIn).toString(),
      );
    });
  });
}
