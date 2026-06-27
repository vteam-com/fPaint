library;

// ignore_for_file: use_build_context_synchronously

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/main.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/halftone_fill.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/tolerance_picker.dart';
import 'package:fpaint/widgets/top_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/painting_test_helpers.dart';

part 'painting_scenario_layers/paint_layer_birds.dart';
part 'painting_scenario_layers/paint_layer_clouds.dart';
part 'painting_scenario_layers/paint_layer_fence.dart';
part 'painting_scenario_layers/paint_layer_house.dart';
part 'painting_scenario_layers/paint_layer_lake.dart';
part 'painting_scenario_layers/paint_layer_land.dart';
part 'painting_scenario_layers/paint_layer_mountains.dart';
part 'painting_scenario_layers/paint_layer_shadows.dart';
part 'painting_scenario_layers/paint_layer_signature.dart';
part 'painting_scenario_layers/paint_layer_sky.dart';
part 'painting_scenario_layers/paint_layer_sun.dart';
part 'painting_scenario_layers/scenario_coverage_exercises.dart';
part 'painting_scenario_layers/scenario_crop_canvas.dart';
part 'painting_scenario_layers/scenario_export_outputs.dart';
part 'painting_scenario_layers/scenario_post_crop_vignette.dart';
part 'painting_scenario_layers/scenario_validate_scene.dart';

// ---------------------------------------------------------------------------
// Test constants
// ---------------------------------------------------------------------------

const String _testLanguageCode = 'en';
const double _testSidePanelSplitHeight = 400.0;
const Map<String, Object> _testPreferences = <String, Object>{
  AppPreferences.keyLanguageCode: _testLanguageCode,
  AppPreferences.keySidePanelDistance: _testSidePanelSplitHeight,
};

const double _scenarioViewportHeightScale = 1.5;
const int _coverageDialogTransitionMs = 300;
const Duration _paintingScenarioTestTimeout = Duration(minutes: 20);
const int _scenarioTimingSecondsPerMinute = 60;
const int _scenarioTimingMillisecondsPerSecond = 1000;

// Sky layer
const String _skyLayerName = 'Sky';
const Offset _skyGradientTop = Offset(0, -20);
const Offset _skyGradientBottom = Offset(0, -240);
const Color _skyColorTop = ui.Color.fromARGB(255, 14, 52, 120); // deep navy at zenith
const Color _skyColorUpperMid = Color.fromARGB(255, 27, 87, 155); // royal blue (upper third)
const Color _skyColorLowerMid = Color.fromARGB(255, 56, 119, 200); // medium sky blue (lower two-thirds)
const Color _skyColorBottom = Color.fromARGB(255, 110, 161, 219); // pale horizon blue
const double _skyUpperMidStopPosition = 0.25;
const double _skyLowerMidStopPosition = 0.60;

// Mountains layer
const String _mountainsLayerName = 'Mountains';
const Color _mountainGradientTopColor = ui.Color.fromARGB(255, 187, 220, 220);
const Color _mountainGradientBlueColor = ui.Color.fromARGB(255, 8, 126, 185);
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
const double _mountainBlurIntensity = 0.2;
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
const double _sunSoftenIntensity = 0.5;

// Land layer
const String _landLayerName = 'Land';
const double _landTopY = 10.0;
const double _landBottomY = 300.0;
const Offset _landTopLeft = Offset(-300, _landTopY);
const Offset _landBottomRight = Offset(300, _landBottomY);
const double _landBorderBrushSize = 0.0;
const double _landNoiseIntensity = 1.0;

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
const double _pondMidStopPosition = 0.65;
const double _pondHighlightBrushSize = AppStroke.thin;
const Color _pondHighlightColor = Color.fromARGB(200, 255, 255, 255);
const double _pondSunReflectionCenterX = (-200.0 + _pondCenterX) / AppMath.pair;
const Color _pondSunReflectionColor = Color.fromARGB(150, 255, 245, 190);
const double _pondSunReflectionBrushSize = 8.0;
const double _pondRippleSoftenIntensity = 0.6;
const double _pondReflectionPixelateIntensity = 0.6;
const double _pondReflectionBlurIntensity = 0.7;
const List<Offset> _pondSunReflectionStreak1 = <Offset>[
  Offset(_pondSunReflectionCenterX - 55, 46),
  Offset(_pondSunReflectionCenterX - 30, 52),
  Offset(_pondSunReflectionCenterX, 49),
  Offset(_pondSunReflectionCenterX + 30, 55),
  Offset(_pondSunReflectionCenterX + 55, 51),
];
const List<Offset> _pondSunReflectionStreak2 = <Offset>[
  Offset(_pondSunReflectionCenterX - 65, 64),
  Offset(_pondSunReflectionCenterX - 35, 70),
  Offset(_pondSunReflectionCenterX, 67),
  Offset(_pondSunReflectionCenterX + 35, 72),
  Offset(_pondSunReflectionCenterX + 65, 68),
];
const List<Offset> _pondSunReflectionStreak3 = <Offset>[
  Offset(_pondSunReflectionCenterX - 70, 84),
  Offset(_pondSunReflectionCenterX - 38, 90),
  Offset(_pondSunReflectionCenterX, 87),
  Offset(_pondSunReflectionCenterX + 38, 92),
  Offset(_pondSunReflectionCenterX + 70, 88),
];
const List<Offset> _pondSunReflectionStreak4 = <Offset>[
  Offset(_pondSunReflectionCenterX - 60, 104),
  Offset(_pondSunReflectionCenterX - 32, 110),
  Offset(_pondSunReflectionCenterX, 107),
  Offset(_pondSunReflectionCenterX + 32, 112),
  Offset(_pondSunReflectionCenterX + 60, 108),
];
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
const double _houseHorizontalShift = 20.0;
const Offset _houseBodyStart = Offset(_houseHorizontalShift, 0);
const Offset _houseBodyEnd = Offset(200 + _houseHorizontalShift, 100);
const Color _houseBodyHalftoneBackgroundColor = Color.fromARGB(255, 255, 216, 229);
const Color _houseBodyHalftoneDotColor = Color.fromARGB(255, 248, 163, 191);
const double _houseBodyHalftoneMaxDotSizeFactor = AppVisual.half;
const Offset _houseDoorStart = Offset(130 + _houseHorizontalShift, 24);
const Offset _houseDoorEnd = Offset(180 + _houseHorizontalShift, 100);
const Offset _houseWindowStart = Offset(20 + _houseHorizontalShift, 30);
const Offset _houseWindowEnd = Offset(80 + _houseHorizontalShift, 50);

// Roof — converging vertical stripes drawn on the House layer.
// Bottom edge of the roof (wider).
const double _roofBaseLeft = -10.0 + _houseHorizontalShift;
const double _roofBaseRight = 210.0 + _houseHorizontalShift;
const double _roofBaseY = 2.0;
// Top edge of the roof (narrower, creating perspective).
const double _roofTopLeft = 45.0 + _houseHorizontalShift;
const double _roofTopRight = 155.0 + _houseHorizontalShift;
const double _roofTopY = -108.0;
const int _roofStripeCount = 18;
const double _roofStripeBrushSize = 14.0;

// Fence shadow via wand-select + fill + skew
const Color _shadowColor = Color.fromARGB(50, 100, 0, 180);

// House Shadow layer (wand-select + fill + skew, same technique as fence shadow)
const String _houseShadowLayerName = 'House Shadow';
const int _houseShadowWandTolerance = 75;
const double _houseHeight = 200.0;
const double _houseShadowGroundOffset = 100.0;
const double _houseShadowTopHandleDelta = _houseHeight + _houseShadowGroundOffset;
const double _houseShadowTopLeftHandleXDelta = 20.0;
const double _houseShadowTopRightHandleXDelta = 30.0;
const double _houseShadowTopEdgeHandleXDelta =
    (_houseShadowTopLeftHandleXDelta + _houseShadowTopRightHandleXDelta) / AppMath.pair;
const double _houseShadowLeftEdgeHandleXDelta = _houseShadowTopLeftHandleXDelta / AppMath.pair;
const double _houseShadowRightEdgeHandleXDelta = _houseShadowTopRightHandleXDelta / AppMath.pair;
const double _houseShadowSideEdgeHandleYDelta = _houseShadowTopHandleDelta / AppMath.pair;
final Offset _houseShadowWandTapOffset = Offset(
  (_houseBodyStart.dx + _houseBodyEnd.dx) / AppMath.pair,
  (_houseBodyStart.dy + _houseBodyEnd.dy) / AppMath.pair,
);

// Birds layer
const String _birdsLayerName = 'Birds';
const double _birdBrushSize = 4.0;
const double _birdsVerticalShiftUp = 80.0;
const Offset _bird1Offset = Offset(-20, -170 - _birdsVerticalShiftUp);
const Offset _bird2Offset = Offset(80, -210 - _birdsVerticalShiftUp);
const Offset _bird3Offset = Offset(150, -150 - _birdsVerticalShiftUp);
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

// Post-crop vignette
const double _vignetteIntensity = 0.3;

// Text
const String _signatureText = 'fPaint';
const String _signatureFontFamily = 'Inter';
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

class _ScenarioPhaseTiming {
  const _ScenarioPhaseTiming({
    required this.label,
    required this.duration,
  });

  final String label;
  final Duration duration;
}

String _formatScenarioDuration(final Duration duration) {
  final int minutes = duration.inMinutes;
  final int seconds = duration.inSeconds.remainder(_scenarioTimingSecondsPerMinute);
  final int milliseconds = duration.inMilliseconds.remainder(_scenarioTimingMillisecondsPerSecond);
  return '${minutes}m ${seconds}s ${milliseconds}ms';
}

Future<void> _runTimedScenarioPhase(
  final List<_ScenarioPhaseTiming> phaseTimings, {
  required final String label,
  required final Future<void> Function() phase,
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  await phase();
  stopwatch.stop();
  phaseTimings.add(
    _ScenarioPhaseTiming(
      label: label,
      duration: stopwatch.elapsed,
    ),
  );
  debugPrint(
    '⏱️ Scenario phase complete: $label (${_formatScenarioDuration(stopwatch.elapsed)})',
  );
}

Future<T> _runTimedScenarioPhaseWithValue<T>(
  final List<_ScenarioPhaseTiming> phaseTimings, {
  required final String label,
  required final Future<T> Function() phase,
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  final T value = await phase();
  stopwatch.stop();
  phaseTimings.add(
    _ScenarioPhaseTiming(
      label: label,
      duration: stopwatch.elapsed,
    ),
  );
  debugPrint(
    '⏱️ Scenario phase complete: $label (${_formatScenarioDuration(stopwatch.elapsed)})',
  );
  return value;
}

void _printScenarioTimingSummary(
  final List<_ScenarioPhaseTiming> phaseTimings, {
  required final Duration totalDuration,
}) {
  final List<_ScenarioPhaseTiming> sortedTimings = List<_ScenarioPhaseTiming>.from(phaseTimings)
    ..sort(
      (final _ScenarioPhaseTiming left, final _ScenarioPhaseTiming right) => right.duration.compareTo(left.duration),
    );

  debugPrint(
    '⏱️ Scenario timing summary (total ${_formatScenarioDuration(totalDuration)}):',
  );
  for (int index = 0; index < sortedTimings.length; index++) {
    final _ScenarioPhaseTiming timing = sortedTimings[index];
    debugPrint(
      '   ${index + 1}. ${timing.label}: ${_formatScenarioDuration(timing.duration)}',
    );
  }
}

void main() {
  SharedPreferences.setMockInitialValues(_testPreferences);

  group('Painting Scenario (Unit Test)', () {
    /// Painting scenario runs entirely in unit tests without a simulator
    testWidgets('Draw house', (final WidgetTester tester) async {
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

      final Stopwatch scenarioStopwatch = Stopwatch()..start();
      final List<_ScenarioPhaseTiming> phaseTimings = <_ScenarioPhaseTiming>[];

      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'sky',
        phase: () => paintLayerSky(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'mountains',
        phase: () => paintLayerMountains(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'clouds',
        phase: () => paintLayerClouds(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'sun',
        phase: () => paintLayerSun(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'land',
        phase: () => paintLayerLand(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'lake',
        phase: () => paintLayerLake(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'house',
        phase: () => paintLayerHouse(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'house shadow',
        phase: () => paintLayerHouseShadow(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'fence',
        phase: () => paintLayerFence(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'fence shadow',
        phase: () => paintLayerFenceShadow(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'birds',
        phase: () => paintLayerBirds(session),
      );

      final LayersProvider layersProvider = await _runTimedScenarioPhaseWithValue<LayersProvider>(
        phaseTimings,
        label: 'crop',
        phase: () => cropScenarioCanvas(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'vignette',
        phase: () => applyPostCropVignette(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'signature',
        phase: () => paintLayerSignature(session, layersProvider: layersProvider),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'validate',
        phase: () => validateScenarioScene(session, layersProvider: layersProvider),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'export',
        phase: () => exportScenarioOutputs(session),
      );

      // Capture the scene state before coverage exercises.
      final int layerCountBefore = layersProvider.length;
      final double canvasWidthBefore = layersProvider.width;
      final double canvasHeightBefore = layersProvider.height;
      final List<String> layerNamesBefore = <String>[
        for (int i = 0; i < layersProvider.length; i++) layersProvider.get(i).name,
      ];
      final List<int> actionCountsBefore = <int>[
        for (int i = 0; i < layersProvider.length; i++) layersProvider.get(i).actionStack.length,
      ];

      videoRecorder.pauseAutoCapture();
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'coverage exercises',
        phase: () => exerciseCoverageScenarios(session),
      );
      videoRecorder.resumeAutoCapture();

      // Each exercise cleans up after itself. Verify the scene is unchanged.
      expect(layersProvider.length, layerCountBefore);
      expect(layersProvider.width, canvasWidthBefore);
      expect(layersProvider.height, canvasHeightBefore);
      for (int i = 0; i < layerCountBefore; i++) {
        expect(layersProvider.get(i).name, layerNamesBefore[i]);
        expect(
          layersProvider.get(i).isVisible,
          isTrue,
          reason: 'Layer "${layersProvider.get(i).name}" at index $i should be visible',
        );
        expect(
          layersProvider.get(i).actionStack.length,
          actionCountsBefore[i],
          reason:
              'Layer "${layersProvider.get(i).name}" actionStack changed from ${actionCountsBefore[i]} to ${layersProvider.get(i).actionStack.length}',
        );
      }

      // Reset the view so the final video frame shows the restored house.
      final AppProvider appProvider = AppProvider.of(
        tester.element(find.byType(MainView)),
        listen: false,
      );
      appProvider.resetView();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'video assembly',
        phase: () => videoRecorder.stop(),
      );

      // Drain any pending debounce timers to avoid a "Pending timers" warning.
      await tester.pump(AppDefaults.debounceDuration);

      scenarioStopwatch.stop();
      _printScenarioTimingSummary(
        phaseTimings,
        totalDuration: scenarioStopwatch.elapsed,
      );

      debugPrint(
        '✅ Full painting scenario completed',
      );
    }, timeout: const Timeout(_paintingScenarioTestTimeout));
  });
}
