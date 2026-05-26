import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/widgets/tool_attribute_widget.dart';

void main() {
  group('ToolAttributeWidget', () {
    testWidgets('renders toggle and content in expanded mode', (
      final WidgetTester tester,
    ) async {
      const Key contentKey = Key('content');
      const Key toggleKey = Key('toggle');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: ToolAttributeWidget(
                  name: 'Halftone',
                  compact: false,
                  enabled: true,
                  enabledToggleKey: toggleKey,
                  onEnabledChanged: _onEnabledChanged,
                  childRight: SizedBox(
                    key: contentKey,
                    height: 32,
                    child: ColoredBox(color: Color(0xFFFF0000)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(toggleKey), findsOneWidget);
      expect(find.byKey(contentKey), findsOneWidget);

      final double toggleY = tester.getTopLeft(find.byKey(toggleKey)).dy;
      final double contentY = tester.getTopLeft(find.byKey(contentKey)).dy;

      expect(toggleY, lessThan(contentY));
    });
  });
}

void _onEnabledChanged(final bool _) {}
