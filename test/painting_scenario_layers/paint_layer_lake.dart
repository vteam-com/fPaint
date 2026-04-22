part of '../painting_scenario_test.dart';

Future<void> paintLayerLake(final PaintingScenarioSession session) async {
  final BuildContext sceneContext = session.tester.element(find.byType(MainView));
  final AppProvider sceneAppProvider = AppProvider.of(sceneContext, listen: false);
  final LayersProvider sceneLayersProvider = LayersProvider.of(sceneContext);
  final int layerCountBeforePond = sceneLayersProvider.length;

  await PaintingLayerHelpers.addNewLayer(session.tester, _pondDraftLayerName);
  await PaintingLayerHelpers.renameLayer(session.tester, _pondLayerName);
  expect(sceneLayersProvider.selectedLayer.name, _pondLayerName);

  final Offset pondCenter = session.canvasCenter + _pondGradientCenter;

  await drawCircleWithHumanGestures(
    session.tester,
    center: pondCenter,
    radius: _pondBaseCircleRadius,
    brushSize: 0,
    brushColor: Colors.transparent,
    fillColor: _pondBaseColor,
  );

  await selectWandArea(
    session.tester,
    position: pondCenter,
    tolerance: _pondWandTolerance,
  );

  await deformSelectionWithTransformOverlay(
    session.tester,
    handleDeltas: _pondTransformHandleDeltas,
  );

  await selectWandArea(
    session.tester,
    position: pondCenter,
    tolerance: _pondWandTolerance,
  );

  await performFloodFillGradient(
    session.tester,
    gradientMode: FillMode.linear,
    gradientPoints: <GradientPoint>[
      GradientPoint(color: _pondColorLight, offset: session.canvasCenter + _pondGradientStart),
      GradientPoint(color: _pondColorMid, offset: pondCenter),
      GradientPoint(color: _pondColorDark, offset: session.canvasCenter + _pondGradientEnd),
    ],
  );

  for (final List<Offset> wavePoints in <List<Offset>>[
    _pondHighlightWave1,
    _pondHighlightWave2,
    _pondHighlightWave3,
  ]) {
    await drawFreehandStrokeWithHumanGestures(
      session.tester,
      points: wavePoints.map((final Offset point) => session.canvasCenter + point).toList(),
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
  await pumpForUnitTestUiSettle(session.tester);

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

  await PaintingLayerHelpers.mergeLayer(session.tester, pondLayerIndex, landLayerIndex);

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

  await session.videoRecorder.captureFrame();
}
