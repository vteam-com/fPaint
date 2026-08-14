import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/widgets/material_free.dart';

void main() {
  group('AppSwitchListTile', () {
    testWidgets('renders and toggles on tap', (WidgetTester tester) async {
      bool value = false;

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (BuildContext context, Widget? child) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return AppSwitchListTile(
                  title: const AppText('Test Switch'),
                  value: value,
                  onChanged: (bool v) {
                    setState(() => value = v);
                  },
                );
              },
            );
          },
        ),
      );

      expect(find.text('Test Switch'), findsOneWidget);

      // Tap the list tile to toggle.
      await tester.tap(find.text('Test Switch'));
      await tester.pump();

      expect(value, isTrue);
    });
  });
}
