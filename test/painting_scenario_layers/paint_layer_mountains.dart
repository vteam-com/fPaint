part of '../painting_scenario_test.dart';

Future<void> paintLayerMountains(final PaintingScenarioSession session) async {
  await _setLayerVisibilityByName(session.tester, layerName: _skyLayerName, isVisible: false);

  // Back mountain: largest and most blurred.
  await PaintingLayerHelpers.addNewLayer(session.tester, _mountainsLayerName);
  await _paintMountainOnSelectedLayer(
    session,
    selectionPoints: _mountainBackSelectionPoints,
    peak: _mountainBackPeak,
    gradientQuickDropPoint: _mountainBackGradientQuickDropPoint,
    fillPoint: _mountainBackFillPoint,
  );
  await applyEffectViaUi(session.tester, SelectionEffect.blur, strength: _mountainBackBlurIntensity);

  // Middle mountain: less blurred than the back mountain.
  await PaintingLayerHelpers.addNewLayer(session.tester, _mountainsMiddleLayerName);
  await _paintMountainOnSelectedLayer(
    session,
    selectionPoints: _mountainMiddleSelectionPoints,
    peak: _mountainMiddlePeak,
    gradientQuickDropPoint: _mountainMiddleGradientQuickDropPoint,
    fillPoint: _mountainMiddleFillPoint,
  );
  await applyEffectViaUi(session.tester, SelectionEffect.blur, strength: _mountainMiddleBlurIntensity);

  // Front mountain: smaller and sharp.
  await PaintingLayerHelpers.addNewLayer(session.tester, _mountainsFrontLayerName);
  await _paintMountainOnSelectedLayer(
    session,
    selectionPoints: _mountainFrontSelectionPoints,
    peak: _mountainFrontPeak,
    gradientQuickDropPoint: _mountainFrontGradientQuickDropPoint,
    fillPoint: _mountainFrontFillPoint,
  );

  await _mergeMountainLayerIntoBase(session, _mountainsFrontLayerName);
  await _mergeMountainLayerIntoBase(session, _mountainsMiddleLayerName);

  final BuildContext mountainContext = session.tester.element(find.byType(MainView));
  final AppProvider mountainAppProvider = AppProvider.of(mountainContext, listen: false);
  mountainAppProvider.selectorModel.clear();
  mountainAppProvider.update();
  await session.tester.pump();

  await _setLayerVisibilityByName(session.tester, layerName: _skyLayerName, isVisible: true);
  await session.videoRecorder.captureFrame();
}

Future<void> _paintMountainOnSelectedLayer(
  final PaintingScenarioSession session, {
  required final List<Offset> selectionPoints,
  required final Offset peak,
  required final Offset gradientQuickDropPoint,
  required final Offset fillPoint,
}) async {
  final Offset snowTransitionPoint = Offset.lerp(peak, gradientQuickDropPoint, _mountainSnowTransitionFactor)!;
  final Offset foothillTransitionPoint = Offset.lerp(
    gradientQuickDropPoint,
    fillPoint,
    _mountainFoothillTransitionFactor,
  )!;

  await selectLassoArea(
    session.tester,
    points: selectionPoints.map((final Offset point) => session.canvasCenter + point).toList(),
  );
  await performFloodFillGradient(
    session.tester,
    gradientMode: FillMode.linear,
    gradientPoints: <GradientPoint>[
      GradientPoint(color: _mountainGradientTopColor, offset: session.canvasCenter + peak),
      GradientPoint(color: _mountainGradientUpperSlopeColor, offset: session.canvasCenter + snowTransitionPoint),
      GradientPoint(color: _mountainGradientLowerSlopeColor, offset: session.canvasCenter + foothillTransitionPoint),
      GradientPoint(color: _mountainGradientBaseColor, offset: session.canvasCenter + fillPoint),
    ],
  );

  await _paintMountainSnowCap(
    session,
    selectionPoints: selectionPoints,
    peak: peak,
    gradientQuickDropPoint: gradientQuickDropPoint,
  );
}

Future<void> _paintMountainSnowCap(
  final PaintingScenarioSession session, {
  required final List<Offset> selectionPoints,
  required final Offset peak,
  required final Offset gradientQuickDropPoint,
}) async {
  final Offset baseLeft = selectionPoints.first;
  final Offset baseRight = selectionPoints[4];
  final Offset capLeft = Offset.lerp(peak, baseLeft, _mountainSnowCapEdgeFactor)!;
  final Offset capRight = Offset.lerp(peak, baseRight, _mountainSnowCapEdgeFactor)!;
  final Offset capBottomMid = Offset.lerp(
    peak,
    Offset((baseLeft.dx + baseRight.dx) / AppMath.pair, gradientQuickDropPoint.dy),
    _mountainSnowCapBottomFactor,
  )!;

  await selectLassoArea(
    session.tester,
    points: <Offset>[
      session.canvasCenter + capLeft,
      session.canvasCenter + peak,
      session.canvasCenter + capRight,
      session.canvasCenter + capBottomMid,
      session.canvasCenter + capLeft,
    ],
  );
  await performFloodFillSolid(
    session.tester,
    position: session.canvasCenter + capBottomMid,
    color: _mountainSnowCapColor,
  );
}

Future<void> _mergeMountainLayerIntoBase(
  final PaintingScenarioSession session,
  final String sourceLayerName,
) async {
  final BuildContext mountainContext = session.tester.element(find.byType(MainView));
  final LayersProvider mountainLayersProvider = LayersProvider.of(mountainContext);

  final int sourceLayerIndex = mountainLayersProvider.list.indexWhere(
    (final LayerProvider layer) => layer.name == sourceLayerName,
  );
  final int mountainsLayerIndex = mountainLayersProvider.list.indexWhere(
    (final LayerProvider layer) => layer.name == _mountainsLayerName,
  );
  expect(sourceLayerIndex, isNonNegative, reason: 'Source mountain layer should exist for merge');
  expect(mountainsLayerIndex, isNonNegative, reason: 'Mountains layer should exist for merge');
  await PaintingLayerHelpers.mergeLayer(session.tester, sourceLayerIndex, mountainsLayerIndex);
}
