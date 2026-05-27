import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/gradient_color_list_editor.dart';

Widget _buildTestApp({
  required final FillModel fillModel,
  required final VoidCallback onChanged,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: GradientColorListEditor(
        fillModel: fillModel,
        onChanged: onChanged,
      ),
    ),
  );
}

FillModel _createModel() {
  final FillModel model = FillModel();
  model.gradientStopColors = <Color>[Colors.red, Colors.blue];
  model.gradientStopPositions = <double>[0.0, 1.0];
  model.gradientPoints = <GradientPoint>[
    GradientPoint(offset: const Offset(0, 0), color: Colors.red),
    GradientPoint(offset: const Offset(100, 0), color: Colors.blue),
  ];
  return model;
}

void main() {
  group('GradientColorListEditor', () {
    testWidgets('shows endpoint labels and add button', (final WidgetTester tester) async {
      final FillModel model = _createModel();

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onChanged: () {},
        ),
      );

      expect(find.byKey(const Key('${Keys.gradientStopPositionKeyPrefixText}0_label')), findsOneWidget);
      expect(find.byKey(const Key('${Keys.gradientStopPositionKeyPrefixText}1_label')), findsOneWidget);
      expect(find.text('0%'), findsWidgets);
      expect(find.text('100%'), findsWidgets);
      expect(find.byKey(Keys.gradientStopAddButton), findsOneWidget);
    });

    testWidgets('adds inner stop with midpoint position and notifies', (final WidgetTester tester) async {
      final FillModel model = _createModel();
      int notifyCount = 0;

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onChanged: () => notifyCount++,
        ),
      );

      await tester.tap(find.byKey(Keys.gradientStopAddButton));
      await tester.pump();

      expect(model.gradientStopColors.length, 3);
      expect(model.gradientStopPositions.length, 3);
      expect(model.gradientStopPositions[0], 0.0);
      expect(model.gradientStopPositions[2], 1.0);
      expect(model.gradientStopPositions[1], closeTo(0.5, 0.001));
      expect(find.byKey(const Key('${Keys.gradientStopPositionKeyPrefixText}1')), findsOneWidget);
      expect(notifyCount, greaterThan(0));
    });

    testWidgets('swaps endpoint colors when only two stops remain', (final WidgetTester tester) async {
      final FillModel model = _createModel();
      int notifyCount = 0;

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onChanged: () => notifyCount++,
        ),
      );

      await tester.tap(find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}0_down')));
      await tester.pump();

      expect(model.gradientStopColors, <Color>[Colors.blue, Colors.red]);
      expect(model.gradientStopPositions, <double>[0.0, 1.0]);
      expect(model.gradientPoints.first.color, Colors.blue);
      expect(model.gradientPoints.last.color, Colors.red);
      expect(notifyCount, greaterThan(0));
    });

    testWidgets('uses disabled tint for unavailable reorder arrows', (final WidgetTester tester) async {
      final FillModel model = _createModel();

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onChanged: () {},
        ),
      );

      final AppButtonIcon firstUp = tester.widget<AppButtonIcon>(
        find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}0_up')),
      );
      final AppButtonIcon firstDown = tester.widget<AppButtonIcon>(
        find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}0_down')),
      );
      final AppButtonIcon lastUp = tester.widget<AppButtonIcon>(
        find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}1_up')),
      );
      final AppButtonIcon lastDown = tester.widget<AppButtonIcon>(
        find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}1_down')),
      );

      expect(firstUp.enabled, isFalse);
      expect(firstUp.color, AppButtonContentSemantic.disabled.color);
      expect(firstDown.enabled, isTrue);
      expect(firstDown.color, isNull);
      expect(lastUp.enabled, isTrue);
      expect(lastUp.color, isNull);
      expect(lastDown.enabled, isFalse);
      expect(lastDown.color, AppButtonContentSemantic.disabled.color);
    });

    testWidgets('middle stops can move in both directions in larger gradients', (final WidgetTester tester) async {
      final FillModel model = _createModel();
      model.gradientStopColors = <Color>[Colors.red, Colors.green, Colors.yellow, Colors.blue];
      model.gradientStopPositions = <double>[0.0, 0.25, 0.75, 1.0];

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onChanged: () {},
        ),
      );

      final AppButtonIcon firstInnerUp = tester.widget<AppButtonIcon>(
        find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}1_up')),
      );
      final AppButtonIcon firstInnerDown = tester.widget<AppButtonIcon>(
        find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}1_down')),
      );
      final AppButtonIcon lastInnerUp = tester.widget<AppButtonIcon>(
        find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}2_up')),
      );
      final AppButtonIcon lastInnerDown = tester.widget<AppButtonIcon>(
        find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}2_down')),
      );

      expect(firstInnerUp.enabled, isTrue);
      expect(firstInnerDown.enabled, isTrue);
      expect(lastInnerUp.enabled, isTrue);
      expect(lastInnerDown.enabled, isTrue);
    });

    testWidgets('swapping with an endpoint keeps endpoint positions fixed', (final WidgetTester tester) async {
      final FillModel model = _createModel();
      model.gradientStopColors = <Color>[Colors.red, Colors.green, Colors.yellow, Colors.blue];
      model.gradientStopPositions = <double>[0.0, 0.25, 0.75, 1.0];

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onChanged: () {},
        ),
      );

      await tester.tap(find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}1_up')));
      await tester.pump();

      expect(model.gradientStopColors, <Color>[Colors.green, Colors.red, Colors.yellow, Colors.blue]);
      expect(model.gradientStopPositions, <double>[0.0, 0.25, 0.75, 1.0]);
      expect(model.gradientPoints.first.color, Colors.green);
      expect(model.gradientPoints.last.color, Colors.blue);
    });

    testWidgets('editable inner position updates model on submit', (final WidgetTester tester) async {
      final FillModel model = _createModel();
      model.gradientStopColors = <Color>[Colors.red, Colors.green, Colors.blue];
      model.gradientStopPositions = <double>[0.0, 0.5, 1.0];

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onChanged: () {},
        ),
      );

      final Finder innerField = find.byKey(const Key('${Keys.gradientStopPositionKeyPrefixText}1'));
      expect(innerField, findsOneWidget);

      await tester.enterText(innerField, '75');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(model.gradientStopPositions[1], closeTo(0.75, 0.001));
      expect(model.gradientStopPositions.first, 0.0);
      expect(model.gradientStopPositions.last, 1.0);
    });

    testWidgets('invalid inner position input is ignored', (final WidgetTester tester) async {
      final FillModel model = _createModel();
      model.gradientStopColors = <Color>[Colors.red, Colors.green, Colors.blue];
      model.gradientStopPositions = <double>[0.0, 0.5, 1.0];

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onChanged: () {},
        ),
      );

      final Finder innerField = find.byKey(const Key('${Keys.gradientStopPositionKeyPrefixText}1'));
      await tester.enterText(innerField, 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(model.gradientStopPositions[1], closeTo(0.5, 0.001));
    });

    testWidgets('removes inner stop and keeps endpoints fixed', (final WidgetTester tester) async {
      final FillModel model = _createModel();
      model.gradientStopColors = <Color>[Colors.red, Colors.green, Colors.blue];
      model.gradientStopPositions = <double>[0.0, 0.6, 1.0];

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onChanged: () {},
        ),
      );

      final Finder removeInner = find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}1_remove'));
      expect(removeInner, findsOneWidget);

      await tester.tap(removeInner);
      await tester.pump();

      expect(model.gradientStopColors.length, 2);
      expect(model.gradientStopPositions.length, 2);
      expect(model.gradientStopPositions.first, 0.0);
      expect(model.gradientStopPositions.last, 1.0);
    });

    testWidgets('reorders inner stop colors while preserving slot positions', (final WidgetTester tester) async {
      final FillModel model = _createModel();
      model.gradientStopColors = <Color>[Colors.red, Colors.green, Colors.yellow, Colors.blue];
      model.gradientStopPositions = <double>[0.0, 0.25, 0.75, 1.0];

      await tester.pumpWidget(
        _buildTestApp(
          fillModel: model,
          onChanged: () {},
        ),
      );

      await tester.tap(find.byKey(const Key('${Keys.gradientStopColorKeyPrefixText}1_down')));
      await tester.pump();

      expect(model.gradientStopColors[1], Colors.yellow);
      expect(model.gradientStopColors[2], Colors.green);
      expect(model.gradientStopPositions[1], closeTo(0.25, 0.001));
      expect(model.gradientStopPositions[2], closeTo(0.75, 0.001));
      expect(model.gradientStopPositions.first, 0.0);
      expect(model.gradientStopPositions.last, 1.0);
    });
  });
}
