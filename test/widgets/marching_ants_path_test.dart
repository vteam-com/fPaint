import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/widgets/marching_ants_path.dart';

void main() {
  group('AnimatedMarchingAntsPath', () {
    testWidgets('renders with a path', (final WidgetTester tester) async {
      final Path testPath = Path()..addRect(const Rect.fromLTWH(10, 10, 100, 100));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedMarchingAntsPath(path: testPath),
        ),
      );

      expect(find.byType(AnimatedMarchingAntsPath), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('renders with line points', (final WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedMarchingAntsPath(
            linePointStart: Offset(10, 10),
            linePointEnd: Offset(200, 200),
          ),
        ),
      );

      expect(find.byType(AnimatedMarchingAntsPath), findsOneWidget);
    });

    testWidgets('renders with both path and line points', (final WidgetTester tester) async {
      final Path testPath = Path()..addRect(const Rect.fromLTWH(10, 10, 100, 100));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedMarchingAntsPath(
            path: testPath,
            linePointStart: const Offset(10, 10),
            linePointEnd: const Offset(200, 200),
          ),
        ),
      );

      expect(find.byType(AnimatedMarchingAntsPath), findsOneWidget);
    });

    testWidgets('renders with no path or line (empty)', (final WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedMarchingAntsPath(),
        ),
      );

      expect(find.byType(AnimatedMarchingAntsPath), findsOneWidget);
    });

    testWidgets('animation ticks correctly', (final WidgetTester tester) async {
      final Path testPath = Path()..addRect(const Rect.fromLTWH(0, 0, 200, 200));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedMarchingAntsPath(path: testPath),
        ),
      );

      // Advance the animation by half its duration
      await tester.pump(AppDefaults.animationLoopDuration ~/ 2);
      expect(find.byType(AnimatedMarchingAntsPath), findsOneWidget);

      // Complete the animation loop
      await tester.pump(AppDefaults.animationLoopDuration ~/ 2);
      expect(find.byType(AnimatedMarchingAntsPath), findsOneWidget);
    });

    testWidgets('disposes correctly', (final WidgetTester tester) async {
      final Path testPath = Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedMarchingAntsPath(path: testPath),
        ),
      );

      // Replace with empty widget to trigger dispose
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      // No errors expected
    });
  });

  group('MarchingAntsPainter', () {
    test('shouldRepaint always returns true', () {
      final MarchingAntsPainter painter = MarchingAntsPainter(
        path: null,
        phase: 0,
        linePointStart: null,
        linePointEnd: null,
      );

      final MarchingAntsPainter other = MarchingAntsPainter(
        path: null,
        phase: 1,
        linePointStart: null,
        linePointEnd: null,
      );

      expect(painter.shouldRepaint(other), isTrue);
    });

    test('paints path without error', () {
      final Path testPath = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
      final MarchingAntsPainter painter = MarchingAntsPainter(
        path: testPath,
        phase: 0.5,
        linePointStart: null,
        linePointEnd: null,
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 200));
      recorder.endRecording();
      // No errors expected
    });

    test('paints line without error', () {
      final MarchingAntsPainter painter = MarchingAntsPainter(
        path: null,
        phase: 0.3,
        linePointStart: const Offset(10, 10),
        linePointEnd: const Offset(190, 190),
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 200));
      recorder.endRecording();
    });

    test('paints both path and line without error', () {
      final Path testPath = Path()..addRect(const Rect.fromLTWH(10, 10, 80, 80));
      final MarchingAntsPainter painter = MarchingAntsPainter(
        path: testPath,
        phase: 0.7,
        linePointStart: const Offset(0, 0),
        linePointEnd: const Offset(100, 100),
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 200));
      recorder.endRecording();
    });

    test('paints empty state without error', () {
      final MarchingAntsPainter painter = MarchingAntsPainter(
        path: null,
        phase: 0,
        linePointStart: null,
        linePointEnd: null,
      );

      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 200));
      recorder.endRecording();
    });
  });
}
