library;

// ignore_for_file: use_build_context_synchronously

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/main.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/painting_test_helpers.dart';

part 'painting_scenario_layers/paint_layer_sky.dart';
part 'painting_scenario_layers/paint_layer_mountains.dart';
part 'painting_scenario_layers/paint_layer_clouds.dart';
part 'painting_scenario_layers/paint_layer_sun.dart';
part 'painting_scenario_layers/paint_layer_land.dart';
part 'painting_scenario_layers/paint_layer_lake.dart';
part 'painting_scenario_layers/paint_layer_shadows.dart';
part 'painting_scenario_layers/paint_layer_house.dart';
part 'painting_scenario_layers/paint_layer_fence.dart';
part 'painting_scenario_layers/paint_layer_birds.dart';
part 'painting_scenario_layers/paint_layer_signature.dart';
part 'painting_scenario_layers/scenario_crop_canvas.dart';
part 'painting_scenario_layers/scenario_validate_scene.dart';
part 'painting_scenario_layers/scenario_export_outputs.dart';

// ---------------------------------------------------------------------------
// Test constants
// ---------------------------------------------------------------------------

const String _testLanguageCode = 'en';
const double _testSidePanelSplitHeight = 400.0;
const Map<String, Object> _testPreferences = <String, Object>{
  AppPreferences.keyLanguageCode: _testLanguageCode,
  AppPreferences.keySidePanelDistance: _testSidePanelSplitHeight,
};

const String _scenarioTestName = 'Painting scenario runs entirely in unit tests without a simulator';
const double _scenarioViewportHeightScale = 1.5;

// Sky layer
const String _skyLayerName = 'Sky';
const Offset _skyGradientTop = Offset(0, -240);
const Offset _skyGradientBottom = Offset(0, -20);
const Color _skyColorTop = ui.Color.fromARGB(255, 27, 87, 155);
const Color _skyColorBottom = Color.fromARGB(255, 110, 161, 219);

// Mountains layer
const String _mountainsLayerName = 'Mountains';
const Color _mountainGradientTopColor = ui.Color.fromARGB(255, 187, 220, 220);
const Color _mountainGradientBlueColor = ui.Color.fromARGB(255, 8, 185, 147);
const Offset _mountain1BaseLeft = Offset(-380, 80);
const Offset _mountain1Peak = Offset(-190, -110);
const Offset _mountain1PeakLeftCurve = Offset(-200, -96);
const Offset _mountain1PeakRightCurve = Offset(-168, -96);
const Offset _mountain1BaseRight = Offset(40, 80);
const Offset _mountain1GradientQuickDropPoint = Offset(-190, -92);
const Offset _mountain1FillPoint = Offset(-190, -24);
const double _mountainDuplicateLargeScaleFactor = 1.35;
const Offset _mountainDuplicateLargeMoveDelta = Offset(-170, -24);
const double _mountainDuplicateSmallScaleFactor = 0.7;
const Offset _mountainDuplicateSmallMoveDelta = Offset(210, 14);
const List<Offset> _mountain1SelectionPoints = <Offset>[
  _mountain1BaseLeft,
  _mountain1PeakLeftCurve,
  _mountain1Peak,
  _mountain1PeakRightCurve,
  _mountain1BaseRight,
  _mountain1BaseLeft,
];

// Clouds layer (drawn with 5 circles and bottom trimmed by selection erase)
const String _cloudsLayerName = 'Clouds';
const Color _cloudFillColor = Color.fromARGB(130, 255, 255, 255);
const Offset _cloud1Center = Offset(110, -182);
const double _cloud1Radius = 30.0;
const Offset _cloud2Center = Offset(130, -190);
const double _cloud2Radius = 58.0;
const Offset _cloud3Center = Offset(200, -212);
const double _cloud3Radius = 100.0;
const Offset _cloud4Center = Offset(270, -190);
const double _cloud4Radius = 60.0;
const Offset _cloud5Center = Offset(290, -180);
const double _cloud5Radius = 44.0;
const Offset _cloudBottomCutoutStart = Offset(80, -180);
const Offset _cloudBottomCutoutEnd = Offset(320, -40);

// Sun layer
const String _sunLayerName = 'Sun';
const Offset _sunOffset = Offset(-200, -220);
const double _sunRadius = 50.0;
const Color _sunRayColorCenter = Color.fromARGB(100, 255, 242, 1);
const Color _sunRayColorEdge = Color.fromARGB(0, 198, 242, 0);
const Color _sunBodyColor = Color.fromARGB(179, 241, 226, 179);

// Land layer
const String _landLayerName = 'Land';
const double _landTopY = 10.0;
const double _landBottomY = 300.0;
const Offset _landTopLeft = Offset(-300, _landTopY);
const Offset _landBottomRight = Offset(300, _landBottomY);

// Lake layer (temporary layer merged into land)
const String _pondDraftLayerName = 'Lake Draft';
const String _pondLayerName = 'Lake';
const double _pondVerticalInsetFactor = 0.2;
const double _pondVerticalBandStartY = _landTopY;
const double _pondVerticalBandEndY = 140;
const double _pondVerticalBandHeight = _pondVerticalBandEndY - _pondVerticalBandStartY;
const double _pondVerticalInset = _pondVerticalBandHeight * _pondVerticalInsetFactor;
const double _pondTopY = _pondVerticalBandStartY + _pondVerticalInset;
const double _pondBottomY = _pondVerticalBandEndY - _pondVerticalInset;
const double _pondCenterY = (_pondTopY + _pondBottomY) / AppMath.pair;
// drawCircleWithHumanGestures passes a horizontal span that becomes the rendered circle diameter.
const double _pondBaseCircleRadius = _pondBottomY - _pondTopY;
const double _pondWidthFactor = 3.0;
const double _pondTargetWidth = _pondBaseCircleRadius * _pondWidthFactor;
const double _pondHorizontalExpansion = (_pondTargetWidth - _pondBaseCircleRadius) / AppMath.pair;
const double _pondCornerHorizontalExpansionFactor = 0.75;
const double _pondCornerHorizontalExpansion = _pondHorizontalExpansion * _pondCornerHorizontalExpansionFactor;
const double _pondCornerVerticalNudge = 2.0;
const double _pondCenterX = -164.0;
const double _pondGradientHalfWidth = _pondTargetWidth / AppMath.pair;
const int _pondWandTolerance = 12;
const Color _pondBaseColor = Color.fromARGB(255, 56, 132, 201);
const Map<TransformOverlayHandle, Offset> _pondTransformHandleDeltas = <TransformOverlayHandle, Offset>{
  TransformOverlayHandle.topLeft: Offset(-_pondCornerHorizontalExpansion, _pondCornerVerticalNudge),
  TransformOverlayHandle.topRight: Offset(_pondCornerHorizontalExpansion, _pondCornerVerticalNudge),
  TransformOverlayHandle.right: Offset(_pondHorizontalExpansion, 0),
  TransformOverlayHandle.bottomRight: Offset(_pondCornerHorizontalExpansion, -_pondCornerVerticalNudge),
  TransformOverlayHandle.bottomLeft: Offset(-_pondCornerHorizontalExpansion, -_pondCornerVerticalNudge),
  TransformOverlayHandle.left: Offset(-_pondHorizontalExpansion, 0),
};
const Offset _pondGradientCenter = Offset(_pondCenterX, _pondCenterY);
const Offset _pondGradientStart = Offset(
  _pondCenterX - _pondGradientHalfWidth,
  _pondCenterY,
);
const Offset _pondGradientEnd = Offset(
  _pondCenterX + _pondGradientHalfWidth,
  _pondCenterY,
);
const Color _pondColorLight = Color.fromARGB(255, 116, 192, 247);
const Color _pondColorMid = Color.fromARGB(255, 49, 132, 206);
const Color _pondColorDark = Color.fromARGB(255, 8, 58, 132);
const double _pondHighlightBrushSize = AppStroke.thin;
const Color _pondHighlightColor = Color.fromARGB(200, 255, 255, 255);
const List<Offset> _pondHighlightWave1 = <Offset>[
  Offset(-236, 63),
  Offset(-220, 57),
  Offset(-204, 63),
  Offset(-188, 57),
  Offset(-172, 62),
  Offset(-156, 56),
];
const List<Offset> _pondHighlightWave2 = <Offset>[
  Offset(-224, 81),
  Offset(-206, 75),
  Offset(-188, 81),
  Offset(-170, 75),
  Offset(-152, 80),
  Offset(-134, 74),
];
const List<Offset> _pondHighlightWave3 = <Offset>[
  Offset(-206, 101),
  Offset(-188, 95),
  Offset(-170, 101),
  Offset(-152, 95),
  Offset(-134, 100),
  Offset(-116, 94),
];

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

// Fence shadow via wand-select + fill + skew
const Color _shadowColor = Color.fromARGB(50, 100, 0, 180);

// House Shadow layer (wand-select + fill + skew, same technique as fence shadow)
const String _houseShadowLayerName = 'House Shadow';
const int _houseShadowWandTolerance = 75;
const double _houseHeight = 200.0;
const double _houseShadowGroundOffset = 100.0;
const double _houseShadowTopHandleDelta = _houseHeight + _houseShadowGroundOffset;
final Offset _houseShadowWandTapOffset = Offset(
  (_houseBodyStart.dx + _houseBodyEnd.dx) / AppMath.pair,
  (_houseBodyStart.dy + _houseBodyEnd.dy) / AppMath.pair,
);

// Birds layer
const String _birdsLayerName = 'Birds';
const double _birdBrushSize = 4.0;
const Offset _bird1Offset = Offset(-20, -170);
const Offset _bird2Offset = Offset(80, -210);
const Offset _bird3Offset = Offset(150, -150);
const Offset _birdPivot = Offset(30, 11);
const double _bird1Scale = 0.9;
const double _bird2Scale = 0.65;
const double _bird3Scale = 1.2;
const double _bird1RotationRadians = -0.08;
const double _bird2RotationRadians = 0.22;
const double _bird3RotationRadians = -0.18;
const double _bird1BrushSize = _birdBrushSize;
const double _bird2BrushSize = 3.0;
const double _bird3BrushSize = 5.0;
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
const String _signatureFontFamily = 'Roboto';
const double _signatureFontSize = 24.0;
const double _signatureMarginRight = 10.0;
const double _signatureMarginBottom = 10.0;
const double _signaturePositionTolerance = 1.0;

// Expected: background + sky + mountains + clouds + sun + land + house + house shadow + fence + fence shadow + birds + signature = 12
const String _backgroundLayerName = 'Background';
const int _expectedLayerCountAfterScene = 12;

// Screenshot filenames
const String _finalOraFilename = 'final.ora';
const String _finalPngFilename = 'final.png';
const String _finalJpegFilename = 'final.jpg';
const String _finalTiffFilename = 'final.tif';
const String _finalWebpFilename = 'final.webp';

Offset _transformBirdPoint(
  final Offset topLeft,
  final Offset point, {
  required final double scale,
  required final double rotationRadians,
}) {
  final Offset centeredPoint = point - _birdPivot;
  final Offset scaledPoint = Offset(
    centeredPoint.dx * scale,
    centeredPoint.dy * scale,
  );
  final double cosine = math.cos(rotationRadians);
  final double sine = math.sin(rotationRadians);
  final Offset rotatedPoint = Offset(
    (scaledPoint.dx * cosine) - (scaledPoint.dy * sine),
    (scaledPoint.dx * sine) + (scaledPoint.dy * cosine),
  );

  return topLeft + _birdPivot + rotatedPoint;
}

Future<void> _drawBird(
  final WidgetTester tester, {
  required final Offset canvasCenter,
  required final Offset topLeftOffset,
  required final double scale,
  required final double rotationRadians,
  required final double brushSize,
}) async {
  final Offset birdTopLeft = canvasCenter + topLeftOffset;

  for (final (Offset start, Offset end) in const <(Offset, Offset)>[
    (_birdLine1Start, _birdLine1End),
    (_birdLine2Start, _birdLine2End),
    (_birdLine3Start, _birdLine3End),
    (_birdLine4Start, _birdLine4End),
  ]) {
    await drawLineWithHumanGestures(
      tester,
      startPosition: _transformBirdPoint(
        birdTopLeft,
        start,
        scale: scale,
        rotationRadians: rotationRadians,
      ),
      endPosition: _transformBirdPoint(
        birdTopLeft,
        end,
        scale: scale,
        rotationRadians: rotationRadians,
      ),
      brushSize: brushSize,
      brushColor: Colors.black,
    );
  }
}

class PaintingScenarioSession {
  const PaintingScenarioSession({
    required this.tester,
    required this.canvasCenter,
    required this.videoRecorder,
  });

  final WidgetTester tester;
  final Offset canvasCenter;
  final UnitTestVideoRecorder videoRecorder;
}

Future<void> _setLayerVisibilityByName(
  final WidgetTester tester, {
  required final String layerName,
  required final bool isVisible,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);

  for (int i = 0; i < layersProvider.length; i++) {
    if (layersProvider.get(i).name == layerName) {
      layersProvider.get(i).isVisible = isVisible;
      layersProvider.update();
      await tester.pump();
      break;
    }
  }
}

void main() {
  SharedPreferences.setMockInitialValues(_testPreferences);

  group('Painting Scenario (Unit Test)', () {
    testWidgets(_scenarioTestName, (final WidgetTester tester) async {
      // ---------------------------------------------------------------
      // Boot the full app — no simulator, no emulator, just widget test
      // ---------------------------------------------------------------
      configureTestViewport(tester);

      // Use a taller viewport for this scenario so more of the app UI is visible.
      tester.view.physicalSize = Size(
        tester.view.physicalSize.width,
        tester.view.physicalSize.height * _scenarioViewportHeightScale,
      );
      await tester.pump();

      await tester.pumpWidget(MyApp());
      await pumpForUnitTestUiSettle(tester);
      await prepareCanvasViewport(tester);

      final UnitTestVideoRecorder videoRecorder = UnitTestVideoRecorder(tester);
      await videoRecorder.start();

      final Offset canvasCenter = tester.getCenter(find.byType(MainView));
      final PaintingScenarioSession session = PaintingScenarioSession(
        tester: tester,
        canvasCenter: canvasCenter,
        videoRecorder: videoRecorder,
      );

      await paintLayerSky(session);
      await paintLayerMountains(session);
      await paintLayerClouds(session);
      await paintLayerSun(session);
      await paintLayerLand(session);
      await paintLayerLake(session);
      await paintLayerHouse(session);
      await paintLayerHouseShadow(session);
      await paintLayerFence(session);
      await paintLayerFenceShadow(session);
      await paintLayerBirds(session);

      final LayersProvider layersProvider = await cropScenarioCanvas(session);
      await paintLayerSignature(session, layersProvider: layersProvider);
      await validateScenarioScene(session, layersProvider: layersProvider);
      await exportScenarioOutputs(session);

      await videoRecorder.stop();

      // Drain any pending debounce timers to avoid a "Pending timers" warning.
      await tester.pump(AppDefaults.debounceDuration);

      debugPrint(
        '✅ Full painting scenario completed in unit test — no simulator needed',
      );
    });
  });
}
