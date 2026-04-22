part of '../painting_scenario_test.dart';

Future<void> paintLayerShadows(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _shadowsLayerName);

  final Offset houseShadowStart = _houseBodyStart + _shadowOffset;
  final Offset houseShadowEnd = _houseBodyEnd + _shadowOffset;
  final Offset houseShadowFillPoint = Offset(
    (houseShadowStart.dx + houseShadowEnd.dx) / AppMath.pair,
    (houseShadowStart.dy + houseShadowEnd.dy) / AppMath.pair,
  );

  await drawRectangleWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + houseShadowStart,
    endPosition: session.canvasCenter + houseShadowEnd,
    brushSize: _shadowBrushSize,
    brushColor: _shadowStrokeColor,
    fillColor: _shadowColorNear,
  );
  await performFloodFillGradient(
    session.tester,
    gradientMode: FillMode.linear,
    gradientPoints: <GradientPoint>[
      GradientPoint(offset: session.canvasCenter + houseShadowFillPoint, color: _shadowColorNear),
      GradientPoint(offset: session.canvasCenter + houseShadowFillPoint + _shadowGradientDelta, color: _shadowColorFar),
    ],
  );

  // Select all content on this layer so the transform overlay can operate on it.
  final BuildContext context = session.tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  appProvider.selectAll();
  appProvider.selectedAction = ActionType.selector;
  appProvider.update();
  await session.tester.pump();

  // Skew the shadow to the right so it looks like it is cast by the sun.
  await deformSelectionWithTransformOverlay(
    session.tester,
    handleDeltas: <TransformOverlayHandle, Offset>{
      TransformOverlayHandle.topLeft: const Offset(_shadowSkewRight, 0),
      TransformOverlayHandle.topRight: const Offset(_shadowSkewRight, 0),
    },
  );

  // Dismiss selection.
  appProvider.selectorModel.clear();
  appProvider.update();
  await session.tester.pump();
  await session.videoRecorder.captureFrame();
}
