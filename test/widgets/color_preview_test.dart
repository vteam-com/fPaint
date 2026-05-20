import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_preview.dart';

const double _waterDropIconViewBoxSize = 24.0;
const double _waterDropVisibleWidth = 16.0;
const double _waterDropVisibleHeight = 19.5;
const double _waterDropHorizontalScale = _waterDropIconViewBoxSize / _waterDropVisibleWidth;
const double _waterDropVerticalScale = _waterDropIconViewBoxSize / _waterDropVisibleHeight;
const double _scaleTolerance = 0.000001;
const double _compactPreviewInnerSize = AppSpacing.largest - (AppSpacing.small * AppMath.pair);

void main() {
  group('ColorPreview', () {
    testWidgets('renders the drop through the shared app icon asset without shrinking the preview footprint', (
      final WidgetTester tester,
    ) async {
      const Color previewColor = Color(0xFF3399FF);
      const Size expectedSize = Size(AppLayout.layerPreviewCompactSize, AppLayout.layerPreviewCompactSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ColorPreview(
              color: previewColor,
              minimal: false,
              text: '',
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final Finder previewSurface = find
          .descendant(
            of: find.byType(ColorPreview).first,
            matching: find.byType(GestureDetector),
          )
          .first;

      expect(tester.getSize(previewSurface), expectedSize);

      final Finder iconFinder = find
          .descendant(
            of: find.byType(ColorPreview).first,
            matching: find.byType(AppSvgIcon),
          )
          .first;
      final List<Transform> transforms = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(ColorPreview).first,
              matching: find.byType(Transform),
            ),
          )
          .toList();
      final List<AppSvgIcon> icons = tester
          .widgetList<AppSvgIcon>(
            find.descendant(
              of: find.byType(ColorPreview).first,
              matching: find.byType(AppSvgIcon),
            ),
          )
          .toList();

      expect(iconFinder, findsOneWidget);
      expect(transforms.length, 1);
      expect(icons.length, 1);
      expect(icons.first.icon, AppIcon.waterDrop);
      expect(icons.first.color, previewColor);
      expect(icons.first.size, expectedSize.width);
      expect(transforms.first.transform.storage[0], _waterDropHorizontalScale);
      expect(transforms.first.transform.storage[5], closeTo(_waterDropVerticalScale, _scaleTolerance));
    });

    testWidgets('calls onPressed when tapped', (final WidgetTester tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ColorPreview(
              color: Colors.blue,
              onPressed: () {
                tapCount += 1;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final Finder previewSurface = find
          .descendant(
            of: find.byType(ColorPreview).first,
            matching: find.byType(GestureDetector),
          )
          .first;

      await tester.tap(previewSurface);
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('shows alpha above RGB pairs for displayed color values', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ColorPreview(
              color: const Color(0x803399FF),
              minimal: false,
              text: '3399FF\n80',
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('80'), findsOneWidget);
      expect(find.text('33 99 FF'), findsOneWidget);
      expect(find.text('3399FF\n80'), findsNothing);
    });

    testWidgets('scales stacked text to avoid overflow in compact previews', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: _compactPreviewInnerSize,
              child: ColorPreview(
                color: const Color(0x80FFFFFF),
                minimal: false,
                text: 'FFFFFF\nFF',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('FF'), findsOneWidget);
      expect(find.text('FF FF FF'), findsOneWidget);
    });
  });
}
