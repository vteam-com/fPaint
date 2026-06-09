import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';

void main() {
  testWidgets('overlay controls render feedback and semantic button states', (final WidgetTester tester) async {
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
        (final Widget w) => w is AppTooltip && w.message == 'Confirm',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tapCount, 1);

    final Finder confirmTooltip = find.byWidgetPredicate(
      (final Widget widget) => widget is AppTooltip && widget.message == 'Confirm',
    );
    final Finder confirmButton = find.descendant(
      of: confirmTooltip,
      matching: find.byWidgetPredicate(
        (final Widget widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    final Finder zoomButton = find.ancestor(
      of: find.text('100%'),
      matching: find.byWidgetPredicate(
        (final Widget widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.rectangle,
      ),
    );
    final Finder zoomText = find.descendant(of: zoomButton, matching: find.byType(Text));
    final Finder cancelIcon = find.descendant(
      of: find.byWidgetPredicate((final Widget widget) => widget is AppTooltip && widget.message == 'Cancel'),
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
