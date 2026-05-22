import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/material_free.dart';

const Key _dangerKey = Key('danger-action-box');
const Key _iconKey = Key('icon-action-box');
const Key _secondaryKey = Key('secondary-action-box');
const Key _primaryKey = Key('primary-action-box');

void main() {
  group('AppDialogButtonRow', () {
    testWidgets('places danger left icon center and primary on the far right', (final WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: AppLayout.dialogWidth,
              child: AppButtonRow(
                actions: <Widget>[
                  _TestDialogAction(slot: AppButtonRowSlot.primary, boxKey: _primaryKey),
                  _TestDialogAction(slot: AppButtonRowSlot.icon, boxKey: _iconKey),
                  _TestDialogAction(slot: AppButtonRowSlot.secondary, boxKey: _secondaryKey),
                  _TestDialogAction(slot: AppButtonRowSlot.danger, boxKey: _dangerKey),
                ],
              ),
            ),
          ),
        ),
      );

      final Rect rowRect = tester.getRect(find.byType(AppButtonRow));
      final Offset dangerCenter = tester.getCenter(find.byKey(_dangerKey));
      final Offset iconCenter = tester.getCenter(find.byKey(_iconKey));
      final Offset secondaryCenter = tester.getCenter(find.byKey(_secondaryKey));
      final Offset primaryCenter = tester.getCenter(find.byKey(_primaryKey));

      expect(dangerCenter.dx, lessThan(iconCenter.dx));
      expect(iconCenter.dx, lessThan(secondaryCenter.dx));
      expect(secondaryCenter.dx, lessThan(primaryCenter.dx));
      expect((iconCenter.dx - rowRect.center.dx).abs(), lessThanOrEqualTo(AppSpacing.medium));
    });

    testWidgets('classifies legacy dialog buttons without semantic wrappers', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppDialog(
              actions: <Widget>[
                AppButtonPrimary(
                  onPressed: () {},
                  text: 'Apply',
                ),
                AppButtonText(
                  onPressed: () {},
                  text: 'Cancel',
                ),
              ],
            ),
          ),
        ),
      );

      final Offset cancelCenter = tester.getCenter(find.text('Cancel'));
      final Offset applyCenter = tester.getCenter(find.text('Apply'));

      expect(cancelCenter.dx, lessThan(applyCenter.dx));
      expect((cancelCenter.dy - applyCenter.dy).abs(), lessThanOrEqualTo(AppSpacing.small));
    });

    testWidgets('stacks trailing actions vertically when width is too small', (final WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 120,
              child: AppButtonRow(
                actions: <Widget>[
                  _TestDialogAction(slot: AppButtonRowSlot.secondary, boxKey: _secondaryKey),
                  _TestDialogAction(slot: AppButtonRowSlot.primary, boxKey: _primaryKey),
                ],
              ),
            ),
          ),
        ),
      );

      final Offset secondaryCenter = tester.getCenter(find.byKey(_secondaryKey));
      final Offset primaryCenter = tester.getCenter(find.byKey(_primaryKey));

      expect(secondaryCenter.dy, lessThan(primaryCenter.dy));
      expect((secondaryCenter.dx - primaryCenter.dx).abs(), lessThanOrEqualTo(AppSpacing.small));
    });
  });
}

class _TestDialogAction extends AppButtonRowWidget {
  const _TestDialogAction({
    required this.slot,
    required this.boxKey,
  });

  final Key boxKey;

  @override
  final AppButtonRowSlot slot;

  @override
  Widget build(final BuildContext context) {
    return SizedBox(
      key: boxKey,
      width: AppSpacing.largest,
      height: AppSpacing.large,
    );
  }
}
