import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/tool_attribute_widget.dart';

void main() {
  group('ToolAttributeWidget', () {
    testWidgets('reveals expanded content after enabling it', (
      final WidgetTester tester,
    ) async {
      const Key contentKey = Key('content');
      const Key toggleKey = Key('toggle');
      bool isEnabled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (final BuildContext context, final StateSetter setState) {
                  return SizedBox(
                    width: 240,
                    child: ToolAttributeWidget(
                      name: 'Halftone',
                      compact: false,
                      enabled: isEnabled,
                      enabledToggleKey: toggleKey,
                      onEnabledChanged: (final bool value) {
                        setState(() {
                          isEnabled = value;
                        });
                      },
                      childRight: const SizedBox(
                        key: contentKey,
                        height: 32,
                        child: ColoredBox(color: Color(0xFFFF0000)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(toggleKey), findsOneWidget);

      expect(find.byKey(contentKey), findsNothing);

      await tester.tap(find.byKey(toggleKey));
      await tester.pump();
      await tester.pump(AppDefaults.toolPanelRevealAnimationDuration);

      expect(find.byKey(contentKey), findsOneWidget);

      final double toggleY = tester.getTopLeft(find.byKey(toggleKey)).dy;
      final double contentY = tester.getTopLeft(find.byKey(contentKey)).dy;

      expect(toggleY, lessThan(contentY));
    });
  });
}
