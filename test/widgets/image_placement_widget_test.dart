import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/image_placement_model.dart';
import 'package:fpaint/widgets/image_placement_widget.dart';

const double _hostWidth = 400.0;
const double _hostHeight = 400.0;
const int _testImageWidth = 100;
const int _testImageHeight = 60;
const Offset _initialImagePosition = Offset(80, 120);

Future<ui.Image> _createTestImage() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _testImageWidth.toDouble(), _testImageHeight.toDouble()),
    Paint()..color = Colors.orange,
  );
  return recorder.endRecording().toImage(_testImageWidth, _testImageHeight);
}

void main() {
  testWidgets('image placement rotate control uses overlay button size', (final WidgetTester tester) async {
    final ImagePlacementModel model = ImagePlacementModel();
    final ui.Image image = await _createTestImage();
    model.start(
      imageToPlace: image,
      initialPosition: _initialImagePosition,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: _hostWidth,
              height: _hostHeight,
              child: ImagePlacementWidget(
                model: model,
                canvasOffset: Offset.zero,
                canvasScale: 1.0,
                onChanged: () {},
                onConfirm: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder rotateControl = find.byTooltip('Resize / Rotate');

    expect(rotateControl, findsOneWidget);
    expect(
      tester.getSize(rotateControl),
      const Size(
        AppInteraction.imagePlacementButtonSize,
        AppInteraction.imagePlacementButtonSize,
      ),
    );
  });
}
