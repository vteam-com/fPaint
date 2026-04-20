// ignore_for_file: use_build_context_synchronously

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
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
const double _sunRadius = 50.0;
const Color _sunRayColorCenter = Color.fromARGB(100, 255, 242, 1);
const Color _sunRayColorEdge = Color.fromARGB(0, 198, 242, 0);
const Color _sunBodyColor = Color.fromARGB(179, 241, 226, 179);

// Land layer
const String _landLayerName = 'Land';
const Offset _landTopLeft = Offset(-300, 10);
const Offset _landBottomRight = Offset(300, 300);

// Lake layer (temporary layer merged into land)
const String _pondDraftLayerName = 'Lake Draft';
const String _pondLayerName = 'Lake';
const List<Offset> _pondSelectionPoints = <Offset>[
  Offset(-268, 75),
  Offset(-254, 51),
  Offset(-230, 33),
  Offset(-194, 21),
  Offset(-150, 23),
  Offset(-118, 31),
  Offset(-92, 25),
  Offset(-66, 37),
  Offset(-44, 57),
  Offset(-36, 79),
  Offset(-48, 99),
  Offset(-74, 113),
  Offset(-106, 109),
  Offset(-134, 121),
  Offset(-174, 129),
  Offset(-214, 123),
  Offset(-242, 111),
  Offset(-260, 95),
];
const Offset _pondGradientCenter = Offset(-164, 75);
const Offset _pondGradientEdgeOffset = Offset(108, 62);
const Color _pondColorCenter = Color.fromARGB(255, 252, 254, 255);
const Color _pondColorEdge = Color.fromARGB(255, 42, 118, 191);
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

// Fence layer
const String _fenceLayerName = 'Fence';
const double _fenceY = 140.0;
const double _fenceHeight = 80.0;
const double _fencePicketSpacing = 80.0;
const double _fenceStartX = -200.0;
const int _fencePicketCount = 6;
const double _fencePicketBrushSize = 10.0;
const double _fencePicketStripeOffset = 4.0;
const Color _fencePicketCenterColor = Color.fromARGB(255, 231, 214, 187);
const Color _fencePicketRightColor = Color.fromARGB(255, 140, 80, 255);
const Offset _fenceRailTopStart = Offset(-210, 80);
const Offset _fenceRailTopEnd = Offset(300, 90);
const Offset _fenceRailBottomStart = Offset(-210, 110);
const Offset _fenceRailBottomEnd = Offset(300, 120);

// Fence shadow via duplicated layer transform
const String _fenceShadowLayerName = 'Fence Shadow';
const double _fenceShadowCropPadding = 40.0;
const double _fenceShadowSkewX = -140.0;
const double _fenceShadowDownOffset = 0.0;
const double _fenceShadowXOffset = 125.0;
const double _fenceShadowYOffset = 12.0;
const Color _fenceShadowTintColor = Color.fromARGB(190, 0, 60, 0);
const double _fenceShadowLayerOpacity = 0.7;

// Shadows layer (house + fence)
const String _shadowsLayerName = 'Shadows';
const Color _shadowColorNear = Color.fromARGB(190, 0, 60, 0);
const Color _shadowColorFar = Color.fromARGB(0, 0, 60, 0);
const Color _shadowStrokeColor = Colors.transparent;
const double _shadowBrushSize = 0.0;
const Offset _shadowOffset = Offset(30, 20);
const Offset _shadowGradientDelta = Offset(0, 80);

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
const String _signatureFontFamily = 'Roboto';
const double _signatureFontSize = 24.0;
const double _signatureMarginRight = 10.0;
const double _signatureMarginBottom = 10.0;
const double _signaturePositionTolerance = 1.0;

// Expected: background + sky + sun + land + house + fence + birds + signature = 8
// Expected: background + sky + sun + land + shadows + house + fence shadow + fence + birds + signature = 10
const int _expectedLayerCountAfterScene = 10;

// Screenshot filenames
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
      await pumpForUnitTestUiSettle(tester);
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

      await PaintingLayerHelpers.addNewLayer(tester, _sunLayerName);
      final Offset sunCenter = canvasCenter + _sunOffset;
      // ---------------------------------------------------------------
      // Draw Sun (rays gradient + circle)
      // ---------------------------------------------------------------
      await performFloodFillGradient(
        tester,
        gradientMode: FillMode.radial,
        gradientPoints: <GradientPoint>[
          GradientPoint(color: _sunRayColorCenter, offset: Offset(sunCenter.dx / 2, sunCenter.dy)),
          GradientPoint(color: _sunRayColorEdge, offset: sunCenter + const Offset(40, 40)),
        ],
      );

      await videoRecorder.captureFrame();

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
      // Draw Lake (lasso selection + clipped fill/highlights + merge)
      // ---------------------------------------------------------------
      final BuildContext sceneContext = tester.element(find.byType(MainView));
      final AppProvider sceneAppProvider = AppProvider.of(sceneContext, listen: false);
      final LayersProvider sceneLayersProvider = LayersProvider.of(sceneContext);
      final int layerCountBeforePond = sceneLayersProvider.length;

      await PaintingLayerHelpers.addNewLayer(tester, _pondDraftLayerName);
      await PaintingLayerHelpers.renameLayer(tester, _pondLayerName);
      expect(sceneLayersProvider.selectedLayer.name, _pondLayerName);

      await selectLassoArea(
        tester,
        points: _pondSelectionPoints.map((final Offset point) => canvasCenter + point).toList(),
      );

      final Offset pondCenter = canvasCenter + _pondGradientCenter;

      await performFloodFillGradient(
        tester,
        gradientMode: FillMode.radial,
        gradientPoints: <GradientPoint>[
          GradientPoint(color: _pondColorCenter, offset: pondCenter),
          GradientPoint(color: _pondColorEdge, offset: pondCenter + _pondGradientEdgeOffset),
        ],
      );

      for (final List<Offset> wavePoints in <List<Offset>>[
        _pondHighlightWave1,
        _pondHighlightWave2,
        _pondHighlightWave3,
      ]) {
        await drawFreehandStrokeWithHumanGestures(
          tester,
          points: wavePoints.map((final Offset point) => canvasCenter + point).toList(),
          brushSize: _pondHighlightBrushSize,
          brushColor: _pondHighlightColor,
        );
      }

      expect(
        sceneAppProvider.selectorModel.isVisible,
        isTrue,
        reason: 'Lake selection should remain active while highlights are drawn',
      );

      sceneAppProvider.selectorModel.clear();
      sceneAppProvider.update();
      await pumpForUnitTestUiSettle(tester);

      expect(
        sceneAppProvider.selectorModel.isVisible,
        isFalse,
        reason: 'Lake selection should be dismissed after finishing the lake',
      );

      final int pondLayerIndex = sceneLayersProvider.list.indexWhere(
        (final LayerProvider layer) => layer.name == _pondLayerName,
      );
      final int landLayerIndex = sceneLayersProvider.list.indexWhere(
        (final LayerProvider layer) => layer.name == _landLayerName,
      );

      expect(pondLayerIndex, isNonNegative, reason: 'Pond layer should exist before merge');
      expect(landLayerIndex, isNonNegative, reason: 'Land layer should exist before merge');

      await PaintingLayerHelpers.mergeLayer(tester, pondLayerIndex, landLayerIndex);

      expect(
        sceneLayersProvider.length,
        layerCountBeforePond,
        reason: 'Merging the pond into land should restore the original layer count',
      );
      expect(
        sceneLayersProvider.list.any((final LayerProvider layer) => layer.name == _pondLayerName),
        isFalse,
        reason: 'Pond layer should be removed after merge',
      );

      await videoRecorder.captureFrame();

      // ---------------------------------------------------------------
      // Draw House (body + door + window + roof)
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.addNewLayer(tester, _shadowsLayerName);

      final Offset houseShadowStart = _houseBodyStart + _shadowOffset;
      final Offset houseShadowEnd = _houseBodyEnd + _shadowOffset;
      final Offset houseShadowFillPoint = Offset(
        (houseShadowStart.dx + houseShadowEnd.dx) / AppMath.pair,
        (houseShadowStart.dy + houseShadowEnd.dy) / AppMath.pair,
      );

      // House shadow
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + houseShadowStart,
        endPosition: canvasCenter + houseShadowEnd,
        brushSize: _shadowBrushSize,
        brushColor: _shadowStrokeColor,
        fillColor: _shadowColorNear,
      );
      await performFloodFillGradient(
        tester,
        gradientMode: FillMode.linear,
        gradientPoints: <GradientPoint>[
          GradientPoint(offset: canvasCenter + houseShadowFillPoint, color: _shadowColorNear),
          GradientPoint(offset: canvasCenter + houseShadowFillPoint + _shadowGradientDelta, color: _shadowColorFar),
        ],
      );

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

      await videoRecorder.captureFrame();

      // ---------------------------------------------------------------
      // Draw Fence (pickets + rails)
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.addNewLayer(tester, _fenceLayerName);

      for (int i = 0; i < _fencePicketCount; i++) {
        final double picketX = _fenceStartX + (i * _fencePicketSpacing);
        for (final (double offsetX, Color color) in <(double, Color)>[
          (-_fencePicketStripeOffset, Colors.white),
          (_fencePicketStripeOffset, _fencePicketRightColor),
          (0, _fencePicketCenterColor),
        ]) {
          await drawLineWithHumanGestures(
            tester,
            startPosition: canvasCenter + Offset(picketX + offsetX, _fenceY),
            endPosition: canvasCenter + Offset(picketX + offsetX, _fenceY - _fenceHeight),
            brushSize: _fencePicketBrushSize,
            brushColor: color,
          );
        }
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
      // Fence shadow (duplicate fence layer, flip vertically, skew)
      // ---------------------------------------------------------------
      await tester.runAsync(() async {
        final BuildContext context = tester.element(find.byType(MainView));
        final LayersProvider layersProvider = LayersProvider.of(context);
        final Offset canvasCenterInCanvas = Offset(
          layersProvider.size.width / AppMath.pair,
          layersProvider.size.height / AppMath.pair,
        );

        final int fenceIndex = layersProvider.list.indexWhere((final LayerProvider l) => l.name == _fenceLayerName);
        if (fenceIndex == -1) {
          throw StateError('Fence layer not found');
        }

        final LayerProvider fenceLayer = layersProvider.get(fenceIndex);
        final ui.Image fenceImage = fenceLayer.toImageForStorage(layersProvider.size);

        final double cropLeft = canvasCenterInCanvas.dx + _fenceRailTopStart.dx - _fenceShadowCropPadding;
        final double cropTop = canvasCenterInCanvas.dy + (_fenceY - _fenceHeight) - _fenceShadowCropPadding;
        final double cropWidth =
            (_fenceRailTopEnd.dx - _fenceRailTopStart.dx) + (_fenceShadowCropPadding * AppMath.pair);
        final double cropHeight = _fenceHeight + (_fenceShadowCropPadding * AppMath.pair);

        final ui.Image croppedFence = cropImage(
          fenceImage,
          ui.Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight),
        );

        final ui.PictureRecorder flipRecorder = ui.PictureRecorder();
        final Canvas flipCanvas = Canvas(flipRecorder);
        flipCanvas.translate(0, croppedFence.height.toDouble());
        flipCanvas.scale(AppVisual.full, -AppVisual.full);
        flipCanvas.drawImage(
          croppedFence,
          Offset.zero,
          Paint()
            ..colorFilter = const ColorFilter.mode(_fenceShadowTintColor, BlendMode.srcIn)
            ..filterQuality = FilterQuality.high,
        );
        final ui.Image flippedFence = await flipRecorder.endRecording().toImage(
          croppedFence.width,
          croppedFence.height,
        );

        final double shadowTopY = canvasCenterInCanvas.dy + _fenceY + _fenceShadowDownOffset + _fenceShadowYOffset;
        final double shadowHeight = cropHeight * AppVisual.half;

        final Offset dstTopLeft = Offset(cropLeft + _fenceShadowXOffset + _fenceShadowSkewX, shadowTopY);
        final Offset dstTopRight = Offset(cropLeft + cropWidth + _fenceShadowXOffset + _fenceShadowSkewX, shadowTopY);
        final Offset dstBottomRight = Offset(cropLeft + cropWidth + _fenceShadowXOffset, shadowTopY + shadowHeight);
        final Offset dstBottomLeft = Offset(cropLeft + _fenceShadowXOffset, shadowTopY + shadowHeight);

        final List<Offset> corners = <Offset>[dstTopLeft, dstTopRight, dstBottomRight, dstBottomLeft];
        final ui.Image skewedShadow = await renderTransformedImage(
          flippedFence,
          corners,
          AppInteraction.transformGridSubdivisions,
        );

        final double minX = <double>[
          dstTopLeft.dx,
          dstTopRight.dx,
          dstBottomRight.dx,
          dstBottomLeft.dx,
        ].reduce((final double a, final double b) => a < b ? a : b);
        final double maxX = <double>[
          dstTopLeft.dx,
          dstTopRight.dx,
          dstBottomRight.dx,
          dstBottomLeft.dx,
        ].reduce((final double a, final double b) => a > b ? a : b);
        final double minY = <double>[
          dstTopLeft.dy,
          dstTopRight.dy,
          dstBottomRight.dy,
          dstBottomLeft.dy,
        ].reduce((final double a, final double b) => a < b ? a : b);
        final double maxY = <double>[
          dstTopLeft.dy,
          dstTopRight.dy,
          dstBottomRight.dy,
          dstBottomLeft.dy,
        ].reduce((final double a, final double b) => a > b ? a : b);

        final LayerProvider shadowLayer = layersProvider.insertAt(fenceIndex, _fenceShadowLayerName);
        shadowLayer.opacity = _fenceShadowLayerOpacity;
        shadowLayer.actionStack.add(
          UserActionDrawing(
            action: ActionType.image,
            positions: <Offset>[
              Offset(minX, minY),
              Offset(maxX, maxY),
            ],
            image: skewedShadow,
          ),
        );
        shadowLayer.hasChanged = true;
        shadowLayer.clearCache();

        fenceImage.dispose();
        croppedFence.dispose();
        flippedFence.dispose();
      });
      await tester.pump();

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
      // Crop canvas to grass bounds (top-anchored) via canvas settings UI
      // ---------------------------------------------------------------
      final BuildContext context = tester.element(find.byType(MainScreen));
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

      await resizeCanvasViaUI(
        tester,
        width: cropTargetSize.width.toInt(),
        height: cropTargetSize.height.toInt(),
        position: CanvasResizePosition.top,
      );
      await prepareCanvasViewport(tester);
      await pumpForUnitTestUiSettle(tester);

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
      // Draw Signature (text via UI — after crop so it uses final canvas size)
      // ---------------------------------------------------------------
      await PaintingLayerHelpers.addNewLayer(tester, _signatureLayerName);

      final Size croppedCanvasSize = layersProvider.size;

      // Compute the bottom-right canvas position for the signature using a
      // temporary TextObject to measure bounds.
      final TextObject measureText = TextObject(
        text: _signatureText,
        position: Offset.zero,
        color: const Color.fromARGB(255, 1, 43, 8),
        size: _signatureFontSize,
        fontFamily: _signatureFontFamily,
        fontWeight: FontWeight.bold,
      );
      final Rect textBounds = measureText.getBounds();

      final Offset signaturePosition = Offset(
        croppedCanvasSize.width - textBounds.width - _signatureMarginRight,
        croppedCanvasSize.height - textBounds.height - _signatureMarginBottom,
      );

      await placeTextViaUI(
        tester,
        canvasPosition: signaturePosition,
        text: _signatureText,
        fontSize: _signatureFontSize,
        color: const Color.fromARGB(255, 1, 43, 8),
        fontWeight: FontWeight.bold,
        fontFamily: _signatureFontFamily,
      );

      final TextObject? signatureTextObject = layersProvider.selectedLayer.actionStack.isEmpty
          ? null
          : layersProvider.selectedLayer.actionStack.last.textObject;
      expect(signatureTextObject, isNotNull, reason: 'Signature layer should contain a text action');
      expect(signatureTextObject!.text, _signatureText);
      expect(signatureTextObject.fontFamily, _signatureFontFamily);
      expect(signatureTextObject.fontWeight, FontWeight.bold);
      expect(signatureTextObject.position.dx, closeTo(signaturePosition.dx, _signaturePositionTolerance));
      expect(signatureTextObject.position.dy, closeTo(signaturePosition.dy, _signaturePositionTolerance));

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

      // Capture final exports through the real main-menu export UI.
      await saveUnitTestArtworkViaExportUi(
        tester,
        format: UnitTestExportFormat.ora,
        filename: _finalOraFilename,
      );

      await saveUnitTestArtworkViaExportUi(
        tester,
        format: UnitTestExportFormat.png,
        filename: _finalPngFilename,
      );

      await saveUnitTestArtworkViaExportUi(
        tester,
        format: UnitTestExportFormat.jpeg,
        filename: _finalJpegFilename,
      );

      await saveUnitTestArtworkViaExportUi(
        tester,
        format: UnitTestExportFormat.tiff,
        filename: _finalTiffFilename,
      );

      await saveUnitTestArtworkViaExportUi(
        tester,
        format: UnitTestExportFormat.webp,
        filename: _finalWebpFilename,
      );
      await dismissOpenUnitTestExportSheet(tester);

      await videoRecorder.stop();

      // Drain any pending debounce timers to avoid a "Pending timers" warning.
      await tester.pump(AppDefaults.debounceDuration);

      debugPrint(
        '✅ Full painting scenario completed in unit test — no simulator needed',
      );
    });
  });
}
