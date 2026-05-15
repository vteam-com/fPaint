import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/transform_model.dart';
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
        child: TransformWidget(
          model: model,
          canvasOffset: Offset.zero,
          canvasScale: 1,
          onChanged: onChanged,
          onConfirm: () {},
          onCancel: () {},
        ),
      ),
    ),
  );
}

void main() {
  group('TransformWidget', () {
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

      await tester.drag(topEdgeZones.first, const Offset(30, 40));
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

      await tester.drag(leftEdgeZones.first, const Offset(0, 40));
      await tester.pump();

      expect(model.corners[TransformModel.topLeftIndex], const Offset(100, 190));
      expect(model.corners[TransformModel.bottomLeftIndex], const Offset(100, 290));
      expect(model.edgeMidpoints[TransformModel.leftEdgeIndex], const Offset(100, 240));
      expect(model.corners[TransformModel.topRightIndex], const Offset(300, 150));
      expect(model.corners[TransformModel.bottomRightIndex], const Offset(300, 250));
    });
  });
}
