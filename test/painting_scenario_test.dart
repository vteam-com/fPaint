// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/main.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/painting_test_helpers.dart';

// ---------------------------------------------------------------------------
// Test constants
// ---------------------------------------------------------------------------

const String _testLanguageCode = 'en';
const Map<String, Object> _testPreferences = <String, Object>{
  AppPreferences.keyLanguageCode: _testLanguageCode,
};

const String _scenarioTestName = 'Painting scenario runs entirely in unit tests without a simulator';

// Sky layer
const String _skyLayerName = 'Sky';
const Offset _skyGradientTop = Offset(0, -240);
const Offset _skyGradientBottom = Offset(0, -20);
const Color _skyColorTop = Color.fromARGB(255, 34, 97, 168);
const Color _skyColorBottom = Color.fromARGB(255, 110, 161, 219);

// Sun layer
const String _sunLayerName = 'Sun';
const Offset _sunOffset = Offset(-200, -220);
const double _sunRadius = 70.0;
const double _sunRayRadius = 400.0;
const Color _sunRayColorCenter = Color.fromARGB(255, 255, 242, 1);
const Color _sunRayColorEdge = Color.fromARGB(59, 0, 28, 242);
const Color _sunBodyColor = Color.fromARGB(179, 241, 226, 179);

// Land layer
const String _landLayerName = 'Land';
const Offset _landTopLeft = Offset(-300, 10);
const Offset _landBottomRight = Offset(300, 300);

// House layer
const String _houseLayerName = 'House';
const Offset _houseBodyStart = Offset(0, 0);
const Offset _houseBodyEnd = Offset(200, 100);
const Offset _houseDoorStart = Offset(130, 24);
const Offset _houseDoorEnd = Offset(180, 88);
const Offset _houseWindowStart = Offset(20, 30);
const Offset _houseWindowEnd = Offset(80, 50);
const Offset _roofLeft = Offset(-5, 0);
const Offset _roofPeak = Offset(100, -100);
const Offset _roofRight = Offset(205, 0);
const Offset _roofFillCanvasPosition = Offset(
  AppLayout.canvasDefaultWidth / 2 + 50,
  AppLayout.canvasDefaultHeight / 2 - 50,
);
const Color _roofFillColor = Color.fromARGB(255, 183, 104, 19);

// Fence layer
const String _fenceLayerName = 'Fence';
const double _fenceY = 140.0;
const double _fenceHeight = 80.0;
const double _fencePicketSpacing = 80.0;
const double _fenceStartX = -200.0;
const int _fencePicketCount = 7;
const double _fencePicketBrushSize = 10.0;
const Offset _fenceRailTopStart = Offset(-210, 80);
const Offset _fenceRailTopEnd = Offset(300, 90);
const Offset _fenceRailBottomStart = Offset(-210, 110);
const Offset _fenceRailBottomEnd = Offset(300, 120);

// Birds layer
const String _birdsLayerName = 'Birds';
const double _birdBrushSize = 4.0;
const Offset _birdOffset = Offset(-20, -170);
const Offset _birdOffset2 = Offset(80, -210);
const Offset _birdOffset3 = Offset(150, -150);
const Offset _birdLine1Start = Offset(4, 18);
const Offset _birdLine1End = Offset(18, 4);
const Offset _birdLine2Start = Offset(18, 4);
const Offset _birdLine2End = Offset(30, 18);
const Offset _birdLine3Start = Offset(30, 18);
const Offset _birdLine3End = Offset(42, 6);
const Offset _birdLine4Start = Offset(42, 6);
const Offset _birdLine4End = Offset(56, 18);

// Signature
const String _signatureLayerName = 'Signature';
const String _signatureText = 'fPaint';
const double _signatureFontSize = 24.0;
const double _signatureMarginRight = 10.0;
const double _signatureMarginBottom = 10.0;

// Expected: background + sky + sun + land + house + fence + birds + signature = 8
const int _expectedLayerCountAfterScene = 8;

// Screenshot filenames
const String _screenshotAfterHouse = 'scenario_house.png';
const String _screenshotFinal = 'scenario_final.png';
const String _finalOraFilename = 'final.ora';
const String _finalPngFilename = 'final.png';
const String _finalJpegFilename = 'final.jpg';
const String _finalTiffFilename = 'final.tif';
const String _finalWebpFilename = 'final.webp';

void main() {
  SharedPreferences.setMockInitialValues(_testPreferences);

  group('Painting Scenario (Unit Test)', () {
    testWidgets(_scenarioTestName, (final WidgetTester tester) async {
      // ---------------------------------------------------------------
      // Boot the full app — no simulator, no emulator, just widget test
      // ---------------------------------------------------------------
      configureTestViewport(tester);
      await tester.pump();

      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      await prepareCanvasViewport(tester);

      final UnitTestVideoRecorder videoRecorder = UnitTestVideoRecorder(tester);
      await videoRecorder.start();

      final Offset canvasCenter = tester.getCenter(find.byType(MainView));

      // ---------------------------------------------------------------
      // Draw Sky (blue gradient)
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.addNewLayer(tester, _skyLayerName);
      await performFloodFillGradient(
        tester,
        gradientMode: FillMode.linear,
        gradientPoints: <GradientPoint>[
          GradientPoint(color: _skyColorTop, offset: canvasCenter + _skyGradientTop),
          GradientPoint(color: _skyColorBottom, offset: canvasCenter + _skyGradientBottom),
        ],
      );
      await videoRecorder.captureFrame();

      // ---------------------------------------------------------------
      // Draw Sun (rays gradient + circle)
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.addNewLayer(tester, _sunLayerName);
      final Offset sunCenter = canvasCenter + _sunOffset;
      await performFloodFillGradient(
        tester,
        gradientMode: FillMode.linear,
        gradientPoints: <GradientPoint>[
          GradientPoint(color: _sunRayColorCenter, offset: sunCenter),
          GradientPoint(color: _sunRayColorEdge, offset: sunCenter + const Offset(_sunRayRadius, _sunRayRadius)),
        ],
      );
      await drawCircleWithHumanGestures(
        tester,
        center: sunCenter,
        radius: _sunRadius,
        brushSize: 0,
        brushColor: Colors.transparent,
        fillColor: _sunBodyColor,
      );
      await videoRecorder.captureFrame();

      // ---------------------------------------------------------------
      // Draw Land (green rectangle)
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.addNewLayer(tester, _landLayerName);
      await tester.pumpAndSettle();

      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + _landTopLeft,
        endPosition: canvasCenter + _landBottomRight,
        brushSize: AppStroke.thin,
        brushColor: Colors.greenAccent,
        fillColor: Colors.green,
      );
      await videoRecorder.captureFrame();

      // ---------------------------------------------------------------
      // Draw House (body + door + window + roof)
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.addNewLayer(tester, _houseLayerName);

      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + _houseBodyStart,
        endPosition: canvasCenter + _houseBodyEnd,
        brushSize: AppStroke.thin,
        brushColor: Colors.white,
        fillColor: const Color.fromARGB(255, 248, 163, 191),
      );

      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + _houseDoorStart,
        endPosition: canvasCenter + _houseDoorEnd,
        brushSize: AppStroke.regular,
        brushColor: Colors.white,
        fillColor: Colors.red,
      );

      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + _houseWindowStart,
        endPosition: canvasCenter + _houseWindowEnd,
        brushSize: AppStroke.regular,
        brushColor: Colors.white,
        fillColor: Colors.grey,
      );

      // Roof lines
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + _roofLeft,
        endPosition: canvasCenter + _roofPeak,
        brushSize: AppStroke.regular,
        brushColor: Colors.orange,
      );
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + _roofRight,
        endPosition: canvasCenter + _roofPeak,
        brushSize: AppStroke.regular,
        brushColor: Colors.orange,
      );
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + _roofLeft,
        endPosition: canvasCenter + _roofRight,
        brushSize: AppStroke.regular,
        brushColor: Colors.orange,
      );

      // Roof fill — use canvas coordinates directly because the zoom-out
      // from prepareCanvasViewport makes screen→canvas conversion unreliable.
      // Zero tolerance prevents leaking through anti-aliased line edges.
      await performFloodFillSolidAtCanvasPosition(
        tester,
        canvasPosition: _roofFillCanvasPosition,
        color: _roofFillColor,
        tolerance: 0,
      );

      await saveUnitTestScreenshot(tester, filename: _screenshotAfterHouse);
      await videoRecorder.captureFrame();

      // ---------------------------------------------------------------
      // Draw Fence (pickets + rails)
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.addNewLayer(tester, _fenceLayerName);

      for (int i = 0; i < _fencePicketCount; i++) {
        final double picketX = _fenceStartX + (i * _fencePicketSpacing);
        await drawLineWithHumanGestures(
          tester,
          startPosition: canvasCenter + Offset(picketX, _fenceY),
          endPosition: canvasCenter + Offset(picketX, _fenceY - _fenceHeight),
          brushSize: _fencePicketBrushSize,
          brushColor: Colors.white,
        );
      }

      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + _fenceRailTopStart,
        endPosition: canvasCenter + _fenceRailTopEnd,
        brushSize: AppStroke.thin,
        brushColor: Colors.grey,
        fillColor: Colors.white,
      );
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + _fenceRailBottomStart,
        endPosition: canvasCenter + _fenceRailBottomEnd,
        brushSize: AppStroke.thin,
        brushColor: Colors.grey,
        fillColor: Colors.white,
      );
      await videoRecorder.captureFrame();

      // ---------------------------------------------------------------
      // Draw Birds (V-shape lines)
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.addNewLayer(tester, _birdsLayerName);

      final Offset birdTopLeft = canvasCenter + _birdOffset;

      await drawLineWithHumanGestures(
        tester,
        startPosition: birdTopLeft + _birdLine1Start,
        endPosition: birdTopLeft + _birdLine1End,
        brushSize: _birdBrushSize,
        brushColor: Colors.black,
      );
      await drawLineWithHumanGestures(
        tester,
        startPosition: birdTopLeft + _birdLine2Start,
        endPosition: birdTopLeft + _birdLine2End,
        brushSize: _birdBrushSize,
        brushColor: Colors.black,
      );
      await drawLineWithHumanGestures(
        tester,
        startPosition: birdTopLeft + _birdLine3Start,
        endPosition: birdTopLeft + _birdLine3End,
        brushSize: _birdBrushSize,
        brushColor: Colors.black,
      );
      await drawLineWithHumanGestures(
        tester,
        startPosition: birdTopLeft + _birdLine4Start,
        endPosition: birdTopLeft + _birdLine4End,
        brushSize: _birdBrushSize,
        brushColor: Colors.black,
      );

      // Bird 2
      final Offset bird2TopLeft = canvasCenter + _birdOffset2;
      for (final (Offset start, Offset end) in <(Offset, Offset)>[
        (_birdLine1Start, _birdLine1End),
        (_birdLine2Start, _birdLine2End),
        (_birdLine3Start, _birdLine3End),
        (_birdLine4Start, _birdLine4End),
      ]) {
        await drawLineWithHumanGestures(
          tester,
          startPosition: bird2TopLeft + start,
          endPosition: bird2TopLeft + end,
          brushSize: _birdBrushSize,
          brushColor: Colors.black,
        );
      }

      // Bird 3
      final Offset bird3TopLeft = canvasCenter + _birdOffset3;
      for (final (Offset start, Offset end) in <(Offset, Offset)>[
        (_birdLine1Start, _birdLine1End),
        (_birdLine2Start, _birdLine2End),
        (_birdLine3Start, _birdLine3End),
        (_birdLine4Start, _birdLine4End),
      ]) {
        await drawLineWithHumanGestures(
          tester,
          startPosition: bird3TopLeft + start,
          endPosition: bird3TopLeft + end,
          brushSize: _birdBrushSize,
          brushColor: Colors.black,
        );
      }
      await videoRecorder.captureFrame();

      // ---------------------------------------------------------------
      // Crop canvas to grass bounds (top-anchored)
      // ---------------------------------------------------------------
      final BuildContext context = tester.element(find.byType(MainScreen));
      final AppProvider appProvider = AppProvider.of(context, listen: false);
      final LayersProvider layersProvider = LayersProvider.of(context);
      final Size preCropCanvasSize = layersProvider.size;
      final int layerCountBeforeCrop = layersProvider.length;
      final Size cropTargetSize = Size(
        _landBottomRight.dx - _landTopLeft.dx,
        (preCropCanvasSize.height / AppMath.pair) + _landBottomRight.dy,
      );

      debugPrint(
        '📐 Cropping canvas: $preCropCanvasSize → '
        '${cropTargetSize.width.toInt()}x${cropTargetSize.height.toInt()}',
      );

      layersProvider.canvasResize(
        cropTargetSize.width.toInt(),
        cropTargetSize.height.toInt(),
        CanvasResizePosition.top,
      );
      appProvider.update();
      await tester.pumpAndSettle();
      await prepareCanvasViewport(tester);
      await tester.pumpAndSettle();

      // Validate crop
      expect(layersProvider.size, cropTargetSize);
      expect(layersProvider.length, layerCountBeforeCrop);
      for (int i = 0; i < layersProvider.length; i++) {
        expect(
          layersProvider.get(i).size,
          cropTargetSize,
          reason: 'Layer "${layersProvider.get(i).name}" size must match canvas after crop',
        );
      }
      debugPrint(
        '✅ Crop validated: ${layersProvider.size.width.toInt()}x'
        '${layersProvider.size.height.toInt()}, '
        '${layersProvider.length} layers',
      );
      await videoRecorder.captureFrame();

      // ---------------------------------------------------------------
      // Draw Signature (text via API — after crop so it uses final canvas size)
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.addNewLayer(tester, _signatureLayerName);

      final Size croppedCanvasSize = layersProvider.size;

      final TextObject signatureTextObject = TextObject(
        text: _signatureText,
        position: Offset.zero,
        color: Colors.white,
        size: _signatureFontSize,
        fontWeight: FontWeight.bold,
      );
      final Rect textBounds = signatureTextObject.getBounds();

      final Offset signaturePosition = Offset(
        croppedCanvasSize.width - textBounds.width - _signatureMarginRight,
        croppedCanvasSize.height - textBounds.height - _signatureMarginBottom,
      );
      signatureTextObject.position = signaturePosition;

      appProvider.recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          action: ActionType.text,
          positions: <Offset>[signaturePosition],
          textObject: signatureTextObject,
        ),
      );
      await tester.pumpAndSettle();
      await videoRecorder.captureFrame();

      // ---------------------------------------------------------------
      // Validate
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.printLayerStructure(tester);

      expect(
        layersProvider.length,
        _expectedLayerCountAfterScene,
        reason: 'Should have background + sky + sun + land + house + fence + birds + signature',
      );

      // Capture final screenshot and save in all supported formats
      await saveUnitTestScreenshot(tester, filename: _screenshotFinal);
      await saveUnitTestOraArchive(tester, filename: _finalOraFilename);
      await saveUnitTestPng(tester, filename: _finalPngFilename);
      await saveUnitTestJpeg(tester, filename: _finalJpegFilename);
      await saveUnitTestTiff(tester, filename: _finalTiffFilename);
      await saveUnitTestWebp(tester, filename: _finalWebpFilename);

      await videoRecorder.stop();

      // Drain any pending debounce timers to avoid a "Pending timers" warning.
      await tester.pump(AppDefaults.debounceDuration);

      debugPrint(
        '✅ Full painting scenario completed in unit test — no simulator needed',
      );
    });
  });
}
