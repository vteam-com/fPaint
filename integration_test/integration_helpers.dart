import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper method to draw a rectangle with human-like gestures
/// Includes automatic rectangle tool selection and natural timing
Future<void> drawRectangleWithHumanGestures(
  final WidgetTester tester, {
  required final Offset startPosition,
  required final Offset endPosition,
  final Duration toolSelectionDelay = const Duration(milliseconds: 400),
}) async {
  // Select rectangle tool (always needed for rectangle drawing)
  await tester.tap(find.byIcon(Icons.crop_square));
  await tester.pump();
  await Future<void>.delayed(toolSelectionDelay);

  final TestGesture gesture = await tester.startGesture(
    startPosition,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );

  // Calculate total movement and divide into 3 human-like steps
  final Offset totalOffset = endPosition - startPosition;
  final Offset stepOffset = totalOffset / 3;

  // Human-like drag with natural timing between steps
  const List<Duration> delays = <Duration>[
    Duration(milliseconds: 200),
    Duration(milliseconds: 250),
    Duration(milliseconds: 150),
  ];

  for (int i = 0; i < 3; i++) {
    await gesture.moveBy(stepOffset);
    if (i < delays.length) {
      await Future<void>.delayed(delays[i]);
    }
    await tester.pump();
  }

  await gesture.up();
  await tester.pump();
}
