import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/tool_attribute_widget.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/widget_test_harness.dart';

const String _rawDangerLabel = 'Erase all';
const String _toggleOnlyName = 'Dither';
const String _builderIdleLabel = 'Builder';
const String _builderPressedLabel = 'Primary';
const Key _toggleOnlyKey = Key('toggle-only');
const Offset _sliderDragDelta = Offset(-40, 0);
const Duration _pressHoldDuration = Duration(milliseconds: 50);

/// A preview builder paired with the name used in failure messages.
typedef _NamedPreview = ({String name, Widget Function() build});

const List<_NamedPreview> _buttonPreviews = <_NamedPreview>[
  (name: 'appButtonTextPreview', build: appButtonTextPreview),
  (name: 'appButtonDangerPreview', build: appButtonDangerPreview),
  (name: 'appButtonPrimaryPreview', build: appButtonPrimaryPreview),
  (name: 'appButtonIconPreview', build: appButtonIconPreview),
  (name: 'appButtonChildPreview', build: appButtonChildPreview),
  (name: 'appRowDangerButtonPreview', build: appRowDangerButtonPreview),
  (name: 'appRowIconButtonPreview', build: appRowIconButtonPreview),
  (name: 'appRowSecondaryButtonPreview', build: appRowSecondaryButtonPreview),
  (name: 'appRowPrimaryButtonPreview', build: appRowPrimaryButtonPreview),
  (name: 'appButtonRowDefaultPreview', build: appButtonRowDefaultPreview),
  (name: 'appButtonRowWithIconPreview', build: appButtonRowWithIconPreview),
  (name: 'appButtonRowCompactPreview', build: appButtonRowCompactPreview),
];

void main() {
  Future<void> pumpInApp(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      buildLocalizedScaffoldTestApp(bodyBuilder: (BuildContext _) => child),
    );
  }

  group('button previews', () {
    for (final _NamedPreview preview in _buttonPreviews) {
      testWidgets('${preview.name} builds and its buttons are tappable', (WidgetTester tester) async {
        await pumpInApp(tester, preview.build());

        expect(tester.takeException(), isNull);
        final Finder buttons = find.byType(AppButton);
        expect(buttons, findsWidgets);
        await tester.tap(buttons.first, warnIfMissed: false);
        await tester.pump();
      });
    }

    testWidgets('appButtonBuilderPreview swaps its label while pressed', (WidgetTester tester) async {
      await pumpInApp(tester, appButtonBuilderPreview());
      expect(find.text(_builderIdleLabel), findsOneWidget);

      final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(AppButton)));
      await tester.pump(_pressHoldDuration);
      expect(find.text(_builderPressedLabel), findsOneWidget);

      await gesture.up();
      await tester.pump();
      await tester.pump();
      expect(find.text(_builderIdleLabel), findsOneWidget);
    });
  });

  group('AppButtonRow with raw buttons', () {
    testWidgets('places a raw AppButtonDanger left and a raw AppButtonIcon in the center slot', (
      WidgetTester tester,
    ) async {
      await pumpInApp(
        tester,
        AppButtonRow(
          actions: <Widget>[
            AppButtonIcon(icon: AppIcon.refresh, onPressed: () {}),
            AppButtonDanger(onPressed: () {}, text: _rawDangerLabel),
          ],
        ),
      );

      final double dangerX = tester.getCenter(find.text(_rawDangerLabel)).dx;
      final double iconX = tester.getCenter(find.byType(AppButtonIcon)).dx;
      expect(dangerX, lessThan(iconX));
    });
  });

  group('ToolAttributeWidget', () {
    testWidgets('preview toggles its title and drags its slider', (WidgetTester tester) async {
      await pumpInApp(tester, Center(child: toolAttributeWidgetPreview()));

      await tester.tap(find.byType(AppButtonText));
      await tester.pump();
      await tester.drag(find.byType(AppSlider), _sliderDragDelta);
      await tester.pump();

      expect(find.byType(ToolAttributeWidget), findsOneWidget);
    });

    testWidgets('a toggle without a right-hand child shows only the dimmed title toggle', (
      WidgetTester tester,
    ) async {
      bool? toggledTo;
      await pumpInApp(
        tester,
        Center(
          child: SizedBox(
            width: AppLayout.sidePanelExpandedMin,
            child: ToolAttributeWidget(
              name: _toggleOnlyName,
              compact: false,
              enabled: false,
              enabledToggleKey: _toggleOnlyKey,
              onEnabledChanged: (bool value) => toggledTo = value,
            ),
          ),
        ),
      );

      final Opacity opacity = tester.widget<Opacity>(
        find.ancestor(of: find.byKey(_toggleOnlyKey), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, AppVisual.disabled);

      await tester.tap(find.byKey(_toggleOnlyKey));
      expect(toggledTo, isTrue);
    });
  });
}
