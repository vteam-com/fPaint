import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/interaction_density.dart';

Widget _iconUnder(InteractionLayoutProfile? profile) {
  const Widget icon = Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: AppSvgIcon(icon: AppIcon.undo)),
  );
  return profile == null ? icon : InteractionDensity(profile: profile, child: icon);
}

void main() {
  group('defaultInteractionInputModality', () {
    test('phones and tablets start in touch so they never open desktop-dense', () {
      expect(defaultInteractionInputModality(TargetPlatform.iOS), InteractionInputModality.touch);
      expect(defaultInteractionInputModality(TargetPlatform.android), InteractionInputModality.touch);
    });

    test('desktops start in mouse', () {
      expect(defaultInteractionInputModality(TargetPlatform.macOS), InteractionInputModality.mouse);
      expect(defaultInteractionInputModality(TargetPlatform.windows), InteractionInputModality.mouse);
      expect(defaultInteractionInputModality(TargetPlatform.linux), InteractionInputModality.mouse);
    });
  });

  group('desktop density', () {
    test('the mouse profile is denser than touch and pen', () {
      expect(AppInteractionProfiles.mouse.iconSize, lessThan(AppInteractionProfiles.touch.iconSize));
      expect(AppInteractionProfiles.mouse.iconSize, lessThan(AppInteractionProfiles.pen.iconSize));
      expect(AppInteractionProfiles.mouse.buttonSpacing, lessThan(AppInteractionProfiles.touch.buttonSpacing));
    });
  });

  group('InteractionDensity', () {
    testWidgets('icons without an explicit size follow the published profile', (WidgetTester tester) async {
      await tester.pumpWidget(_iconUnder(AppInteractionProfiles.mouse));

      expect(tester.getSize(find.byType(AppSvgIcon)), const Size.square(AppLayout.iconSizeDense));
    });

    testWidgets('icons fall back to touch sizing outside any scope', (WidgetTester tester) async {
      await tester.pumpWidget(_iconUnder(null));

      expect(tester.getSize(find.byType(AppSvgIcon)), Size.square(InteractionDensity.fallback.iconSize));
    });

    testWidgets('icons resize when the input modality changes', (WidgetTester tester) async {
      await tester.pumpWidget(_iconUnder(AppInteractionProfiles.mouse));
      await tester.pumpWidget(_iconUnder(AppInteractionProfiles.touch));

      expect(tester.getSize(find.byType(AppSvgIcon)), Size.square(AppInteractionProfiles.touch.iconSize));
    });

    testWidgets('an explicit size still wins over the profile', (WidgetTester tester) async {
      const double explicitSize = 40;
      await tester.pumpWidget(
        const InteractionDensity(
          profile: AppInteractionProfiles.mouse,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: AppSvgIcon(icon: AppIcon.undo, size: explicitSize),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(AppSvgIcon)), const Size.square(explicitSize));
    });
  });
}
