import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('overlay mode handle math', () {
    test('overlayModeHandleCenter steps one button plus spacing per index', () {
      final Offset first = overlayModeHandleCenter(
        rowLeft: 10,
        rowTop: 20,
        buttonSize: 40,
        spacing: 4,
        buttonIndex: overlayTranslateButtonIndex,
      );
      final Offset third = overlayModeHandleCenter(
        rowLeft: 10,
        rowTop: 20,
        buttonSize: 40,
        spacing: 4,
        buttonIndex: overlayRotateButtonIndex,
      );
      expect(first, const Offset(30, 40));
      expect(third, const Offset(118, 40));
    });

    test('scaleFactorForHandleDrag returns the distance ratio, or null on the pivot', () {
      expect(
        scaleFactorForHandleDrag(handleCenter: const Offset(10, 0), pivot: Offset.zero, dragDelta: const Offset(10, 0)),
        closeTo(2, 1e-9),
      );
      expect(
        scaleFactorForHandleDrag(handleCenter: Offset.zero, pivot: Offset.zero, dragDelta: const Offset(10, 0)),
        isNull,
      );
    });

    test('angleDeltaForHandleDrag returns the swept angle around the pivot', () {
      final double angle = angleDeltaForHandleDrag(
        handleCenter: const Offset(10, 0),
        pivot: Offset.zero,
        dragDelta: const Offset(-10, 10),
      );
      expect(angle, closeTo(pi / 2, 1e-9));
    });

    test('overlayControlGroupContentWidth counts gaps between buttons only', () {
      expect(overlayControlGroupContentWidth(buttonSize: 40, spacing: 4, buttonCount: 3), 128);
      expect(overlayControlGroupContentWidth(buttonSize: 40, spacing: 4, buttonCount: 0), 0);
    });

    test('centeredPositioned pins the top-left so the child is centred', () {
      final Positioned positioned = centeredPositioned(
        center: const Offset(50, 60),
        size: const Size(20, 10),
        child: const SizedBox(),
      );
      expect(positioned.left, 40);
      expect(positioned.top, 55);
      expect(positioned.width, isNull);
    });
  });

  testWidgets('overlay controls render feedback and semantic button states', (WidgetTester tester) async {
    int tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              buildOverlayFeedbackBubble(label: '125%'),
              buildOverlayCircleButton(
                tooltip: 'Confirm',
                icon: AppIcon.check,
                cursor: SystemMouseCursors.click,
                onTap: () {
                  tapCount += 1;
                },
              ),
              buildOverlayButton(
                tooltip: 'Zoom',
                cursor: SystemMouseCursors.click,
                width: 96,
                child: const AppText('100%', variant: AppTextVariant.label),
                showBorder: false,
                isSelected: true,
                onTap: () {},
              ),
              buildOverlayCircleButton(
                tooltip: 'Cancel',
                icon: AppIcon.close,
                contentSemantic: AppButtonContentSemantic.dangerous,
                cursor: SystemMouseCursors.click,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('125%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate(
        (Widget w) => w is AppTooltip && w.message == 'Confirm',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tapCount, 1);

    final Finder confirmTooltip = find.byWidgetPredicate(
      (Widget widget) => widget is AppTooltip && widget.message == 'Confirm',
    );
    final Finder confirmButton = find.descendant(
      of: confirmTooltip,
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    final Finder zoomButton = find.ancestor(
      of: find.text('100%'),
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.rectangle,
      ),
    );
    final Finder zoomText = find.descendant(of: zoomButton, matching: find.byType(Text));
    final Finder cancelIcon = find.descendant(
      of: find.byWidgetPredicate((Widget widget) => widget is AppTooltip && widget.message == 'Cancel'),
      matching: find.byType(AppSvgIcon),
    );

    expect(
      (tester.widget<Container>(confirmButton).decoration! as BoxDecoration).color,
      AppColors.buttonBackground,
    );
    expect((tester.widget<Container>(zoomButton).decoration! as BoxDecoration).border, isNull);
    expect((tester.widget<Container>(zoomButton).decoration! as BoxDecoration).color, AppColors.buttonSelected);
    expect(tester.widget<Text>(zoomText).style?.color, AppColors.buttonEnable);
    expect(tester.widget<AppSvgIcon>(cancelIcon).color, AppColors.buttonDanger);

    final TestGesture confirmPress = await tester.startGesture(tester.getCenter(confirmTooltip));
    await tester.pump();

    expect(
      (tester.widget<Container>(confirmButton).decoration! as BoxDecoration).color,
      AppColors.buttonSelected,
    );

    await confirmPress.up();
  });
}
