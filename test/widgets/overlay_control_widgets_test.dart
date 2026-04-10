import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';

void main() {
  testWidgets('overlay controls render feedback and handle taps', (final WidgetTester tester) async {
    int tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              buildOverlayFeedbackBubble(label: '125%'),
              buildOverlayCircleButton(
                tooltip: 'Confirm',
                color: Colors.green,
                cursor: SystemMouseCursors.click,
                onTap: () {
                  tapCount += 1;
                },
                child: const Icon(Icons.check),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('125%'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(tapCount, 1);
  });
}
