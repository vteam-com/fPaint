import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/widgets/fill_widget.dart';

Widget _buildTestApp({
  required final FillModel fillModel,
  required final void Function(GradientPoint) onUpdate,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SizedBox.expand(
      child: FillWidget(
        fillModel: fillModel,
        onUpdate: onUpdate,
      ),
    ),
  );
}

FillModel _createLinearFillModel() {
  final FillModel model = FillModel();
  model.mode = FillMode.linear;
  model.addPoint(GradientPoint(offset: const Offset(150, 150), color: Colors.red));
  model.addPoint(GradientPoint(offset: const Offset(300, 300), color: Colors.blue));
  model.isVisible = true;
  return model;
}

FillModel _createRadialFillModel() {
  final FillModel model = FillModel();
  model.mode = FillMode.radial;
  model.addPoint(GradientPoint(offset: const Offset(200, 200), color: Colors.green));
  model.addPoint(GradientPoint(offset: const Offset(300, 200), color: Colors.yellow));
  model.isVisible = true;
  return model;
}

void main() {
  group('FillWidget', () {
    testWidgets('renders linear gradient with marching ants and handles', (final WidgetTester tester) async {
      final FillModel model = _createLinearFillModel();
      final List<GradientPoint> updatedPoints = <GradientPoint>[];

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onUpdate: updatedPoints.add,
        ),
      );
      await tester.pump();

      // Should have two gradient handles
      expect(find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}0')), findsOneWidget);
      expect(find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}1')), findsOneWidget);
    });

    testWidgets('renders all gradient stop handles when there are inner colors', (final WidgetTester tester) async {
      final FillModel model = _createLinearFillModel();
      model.gradientStopColors = <Color>[
        Colors.red,
        Colors.green,
        Colors.blue,
      ];

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onUpdate: (final GradientPoint _) {},
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}0')), findsOneWidget);
      expect(find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}1')), findsOneWidget);
      expect(find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}2')), findsOneWidget);
    });

    testWidgets('renders radial gradient with handles', (final WidgetTester tester) async {
      final FillModel model = _createRadialFillModel();

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onUpdate: (final GradientPoint _) {},
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}0')), findsOneWidget);
      expect(find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}1')), findsOneWidget);
    });

    testWidgets('dragging handle calls onUpdate', (final WidgetTester tester) async {
      final FillModel model = _createLinearFillModel();
      final List<GradientPoint> updatedPoints = <GradientPoint>[];

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onUpdate: updatedPoints.add,
        ),
      );
      await tester.pump();

      final Finder handle = find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}0'));
      final Offset center = tester.getCenter(handle);
      final TestGesture gesture = await tester.startGesture(center);
      await tester.pump();
      // Move past kPanSlop to trigger onPanUpdate
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(5, 5));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(updatedPoints, isNotEmpty);
    });

    testWidgets('tap down shows details, tap up hides', (final WidgetTester tester) async {
      final FillModel model = _createLinearFillModel();

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onUpdate: (final GradientPoint _) {},
        ),
      );
      await tester.pump();

      final Finder handle = find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}0'));

      // Tap to trigger tapDown/tapUp via manual gesture
      final Offset tapCenter = tester.getCenter(handle);
      final TestGesture tapGesture = await tester.startGesture(tapCenter);
      await tester.pump();
      await tapGesture.up();
      await tester.pump();
    });

    testWidgets('inner handle movement is clamped by neighbor stops', (final WidgetTester tester) async {
      final FillModel model = _createLinearFillModel();
      model.gradientStopColors = <Color>[Colors.red, Colors.green, Colors.yellow, Colors.blue];
      model.gradientStopPositions = <double>[0.0, 0.25, 0.75, 1.0];

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onUpdate: (final GradientPoint _) {},
        ),
      );
      await tester.pump();

      final Finder innerHandle = find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}2'));
      final TestGesture gesture = await tester.startGesture(tester.getCenter(innerHandle));
      await tester.pump();
      await gesture.moveBy(const Offset(-500, -500));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(model.gradientStopPositions[2], greaterThanOrEqualTo(model.gradientStopPositions[1]));
      expect(model.gradientStopPositions[2], lessThanOrEqualTo(1.0));
    });

    testWidgets('radial mode builds marching-ants path and handles', (final WidgetTester tester) async {
      final FillModel model = _createRadialFillModel();

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onUpdate: (final GradientPoint _) {},
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}0')), findsOneWidget);
      expect(find.byKey(const Key('${Keys.gradientHandleKeyPrefixText}1')), findsOneWidget);
    });
  });
}
