import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/widgets/app_tooltip.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';
import 'package:fpaint/widgets/transform_widget.dart';

Future<ui.Image> _createTestImage({
  final int width = 120,
  final int height = 80,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.orange,
  );
  return recorder.endRecording().toImage(width, height);
}

Widget _buildHarness({
  required final TransformModel model,
  required final VoidCallback onChanged,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(size: Size(1200, 900)),
        child: StatefulBuilder(
          builder: (final BuildContext context, final void Function(void Function()) setState) {
            return TransformWidget(
              model: model,
              canvasOffset: Offset.zero,
              canvasScale: 1,
              onChanged: () {
                setState(() {});
                onChanged();
              },
              onConfirm: () {},
              onCancel: () {},
            );
          },
        ),
      ),
    ),
  );
}

Finder _findTransformButton(
  final WidgetTester tester,
) {
  final BuildContext context = tester.element(find.byType(TransformWidget));
  final AppLocalizations l10n = AppLocalizations.of(context)!;

  return _findOverlayButtonByTooltip(tester, l10n.transform);
}

Finder _findTranslateButton(
  final WidgetTester tester,
) {
  final BuildContext context = tester.element(find.byType(TransformWidget));
  final AppLocalizations l10n = AppLocalizations.of(context)!;

  return _findOverlayButtonByTooltip(tester, l10n.translate);
}

Finder _findOverlayButtonByTooltip(
  final WidgetTester tester,
  final String tooltipMessage,
) {
  final Finder transformTooltip = find.byWidgetPredicate(
    (final Widget widget) => widget is AppTooltip && widget.message == tooltipMessage,
  );

  return find
      .descendant(
        of: transformTooltip,
        matching: find.byType(GestureDetector),
      )
      .first;
}

Finder _findTransformHandles() => find.byType(OverlayDragHandle);

void main() {
  group('TransformWidget', () {
    testWidgets('transform button cycles enabled handle groups and only renders active handles', (
      final WidgetTester tester,
    ) async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(100, 150, 200, 100));

      await tester.pumpWidget(
        _buildHarness(
          model: model,
          onChanged: () {},
        ),
      );
      await tester.pump();

      final Finder transformButton = _findTransformButton(tester);
      final Finder handles = _findTransformHandles();

      expect(handles, findsNWidgets(4));
      expect(find.byType(TransformEdgeDragZone), findsNWidgets(8));

      await tester.tap(transformButton);
      await tester.pump();

      expect(handles, findsNWidgets(4));
      expect(find.byType(TransformEdgeDragZone), findsNWidgets(8));

      await tester.tap(transformButton);
      await tester.pump();

      expect(handles, findsNWidgets(9));
      expect(find.byType(TransformEdgeDragZone), findsNWidgets(8));

      await tester.tap(transformButton);
      await tester.pump();

      expect(handles, findsNWidgets(4));
      expect(find.byType(TransformEdgeDragZone), findsNWidgets(8));
    });

    testWidgets('center handle only renders and moves the selection in all-handles mode', (
      final WidgetTester tester,
    ) async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(100, 150, 200, 100));

      await tester.pumpWidget(
        _buildHarness(
          model: model,
          onChanged: () {},
        ),
      );
      await tester.pump();

      final Finder handles = _findTransformHandles();
      final Finder transformButton = _findTransformButton(tester);

      expect(handles, findsNWidgets(4));

      await tester.tap(transformButton);
      await tester.pump();

      expect(handles, findsNWidgets(4));

      await tester.tap(transformButton);
      await tester.pump();

      expect(handles, findsNWidgets(9));

      await tester.drag(handles.at(8), const Offset(20, 30));
      await tester.pump();

      expect(model.center, const Offset(220, 230));
      expect(model.corners[TransformModel.topLeftIndex], const Offset(120, 180));
      expect(model.corners[TransformModel.bottomRightIndex], const Offset(320, 280));
    });

    testWidgets('translate button enables all-handles mode and drags the full selection', (
      final WidgetTester tester,
    ) async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(100, 150, 200, 100));

      await tester.pumpWidget(
        _buildHarness(
          model: model,
          onChanged: () {},
        ),
      );
      await tester.pump();

      final Finder translateButton = _findTranslateButton(tester);
      final Finder handles = _findTransformHandles();

      expect(model.handleSet, TransformHandleSet.corners);
      expect(handles, findsNWidgets(4));

      await tester.tap(translateButton);
      await tester.pump();

      expect(model.handleSet, TransformHandleSet.all);
      expect(model.isTranslateMode, isTrue);
      expect(handles, findsNWidgets(9));

      await tester.drag(translateButton, const Offset(20, 30), warnIfMissed: false);
      await tester.pump();

      final Offset topLeftDelta = model.corners[TransformModel.topLeftIndex] - const Offset(100, 150);
      final Offset bottomRightDelta = model.corners[TransformModel.bottomRightIndex] - const Offset(300, 250);
      final Offset centerDelta = model.center - const Offset(200, 200);

      expect(centerDelta.dx, greaterThan(0));
      expect(centerDelta.dy, greaterThan(0));
      expect(topLeftDelta.dx, closeTo(centerDelta.dx, 0.001));
      expect(topLeftDelta.dy, closeTo(centerDelta.dy, 0.001));
      expect(bottomRightDelta.dx, closeTo(centerDelta.dx, 0.001));
      expect(bottomRightDelta.dy, closeTo(centerDelta.dy, 0.001));
    });

    testWidgets('transform button resets to corners when leaving scale mode', (
      final WidgetTester tester,
    ) async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(100, 150, 200, 100));

      await tester.pumpWidget(
        _buildHarness(
          model: model,
          onChanged: () {},
        ),
      );
      await tester.pump();

      final BuildContext context = tester.element(find.byType(TransformWidget));
      final AppLocalizations l10n = AppLocalizations.of(context)!;
      final Finder transformButton = _findTransformButton(tester);
      final Finder scaleButton = _findOverlayButtonByTooltip(tester, l10n.scale);
      final Finder handles = _findTransformHandles();

      await tester.tap(transformButton);
      await tester.pump();
      await tester.tap(transformButton);
      await tester.pump();

      expect(handles, findsNWidgets(9));
      expect(model.handleSet, TransformHandleSet.all);

      await tester.tap(scaleButton);
      await tester.pump();

      expect(model.isScaleMode, isTrue);

      await tester.tap(transformButton);
      await tester.pump();

      expect(model.isDeformMode, isTrue);
      expect(model.handleSet, TransformHandleSet.corners);
      expect(handles, findsNWidgets(4));
      expect(find.byType(TransformEdgeDragZone), findsNWidgets(8));
    });

    testWidgets('dragging an edge line moves the connected edge points together', (
      final WidgetTester tester,
    ) async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(100, 150, 200, 100));

      int changedCallCount = 0;

      await tester.pumpWidget(
        _buildHarness(
          model: model,
          onChanged: () {
            changedCallCount++;
          },
        ),
      );
      await tester.pump();

      final Finder topEdgeZones = find.byWidgetPredicate(
        (final Widget widget) => widget is TransformEdgeDragZone && widget.edgeIndex == TransformModel.topEdgeIndex,
      );

      expect(topEdgeZones, findsNWidgets(2));

      await tester.drag(topEdgeZones.first, const Offset(30, 40), warnIfMissed: false);
      await tester.pump();

      expect(model.corners[TransformModel.topLeftIndex], const Offset(130, 190));
      expect(model.corners[TransformModel.topRightIndex], const Offset(330, 190));
      expect(model.edgeMidpoints[TransformModel.topEdgeIndex], const Offset(230, 190));
      expect(model.corners[TransformModel.bottomLeftIndex], const Offset(100, 250));
      expect(model.corners[TransformModel.bottomRightIndex], const Offset(300, 250));
      expect(changedCallCount, greaterThan(0));
    });

    testWidgets('dragging a left edge line vertically keeps the movement vertical', (
      final WidgetTester tester,
    ) async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(100, 150, 200, 100));

      await tester.pumpWidget(
        _buildHarness(
          model: model,
          onChanged: () {},
        ),
      );
      await tester.pump();

      final Finder leftEdgeZones = find.byWidgetPredicate(
        (final Widget widget) => widget is TransformEdgeDragZone && widget.edgeIndex == TransformModel.leftEdgeIndex,
      );

      expect(leftEdgeZones, findsNWidgets(2));

      await tester.drag(leftEdgeZones.first, const Offset(0, 40), warnIfMissed: false);
      await tester.pump();

      expect(model.corners[TransformModel.topLeftIndex], const Offset(100, 190));
      expect(model.corners[TransformModel.bottomLeftIndex], const Offset(100, 290));
      expect(model.edgeMidpoints[TransformModel.leftEdgeIndex], const Offset(100, 240));
      expect(model.corners[TransformModel.topRightIndex], const Offset(300, 150));
      expect(model.corners[TransformModel.bottomRightIndex], const Offset(300, 250));
    });
  });
}
