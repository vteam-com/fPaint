part of '../painting_scenario_test.dart';

Future<void> paintLayerMountains(final PaintingScenarioSession session) async {
  await _setLayerVisibilityByName(session.tester, layerName: _skyLayerName, isVisible: false);
  await PaintingLayerHelpers.addNewLayer(session.tester, _mountainsLayerName);

  await selectLassoArea(
    session.tester,
    points: _mountain1SelectionPoints.map((final Offset point) => session.canvasCenter + point).toList(),
  );
  await performFloodFillGradient(
    session.tester,
    gradientMode: FillMode.linear,
    gradientPoints: <GradientPoint>[
      GradientPoint(color: _mountainGradientTopColor, offset: session.canvasCenter + _mountain1Peak),
      GradientPoint(color: _mountainGradientBlueColor, offset: session.canvasCenter + _mountain1GradientQuickDropPoint),
      GradientPoint(
        color: const ui.Color.fromARGB(255, 0, 112, 30),
        offset: session.canvasCenter + _mountain1FillPoint,
      ),
    ],
  );

  final BuildContext mountainContext = session.tester.element(find.byType(MainView));
  final AppProvider mountainAppProvider = AppProvider.of(mountainContext, listen: false);
  final LayersProvider mountainLayersProvider = LayersProvider.of(mountainContext);

  await _duplicateSelectedMountain(
    session,
    mountainAppProvider: mountainAppProvider,
    moveDelta: _mountainDuplicateLargeMoveDelta,
    scaleFactor: _mountainDuplicateLargeScaleFactor,
  );
  final LayerProvider firstDuplicateLayer = mountainLayersProvider.selectedLayer;

  await _duplicateSelectedMountain(
    session,
    mountainAppProvider: mountainAppProvider,
    moveDelta: _mountainDuplicateSmallMoveDelta,
    scaleFactor: _mountainDuplicateSmallScaleFactor,
  );
  final LayerProvider secondDuplicateLayer = mountainLayersProvider.selectedLayer;

  int mountainsLayerIndex = mountainLayersProvider.list.indexWhere(
    (final LayerProvider layer) => layer.name == _mountainsLayerName,
  );
  final int secondDuplicateLayerIndex = mountainLayersProvider.list.indexOf(secondDuplicateLayer);
  expect(secondDuplicateLayerIndex, isNonNegative, reason: 'Second duplicated mountain layer should exist');
  expect(mountainsLayerIndex, isNonNegative, reason: 'Mountains layer should exist for merge');
  await PaintingLayerHelpers.mergeLayer(session.tester, secondDuplicateLayerIndex, mountainsLayerIndex);

  mountainsLayerIndex = mountainLayersProvider.list.indexWhere(
    (final LayerProvider layer) => layer.name == _mountainsLayerName,
  );
  final int firstDuplicateLayerIndex = mountainLayersProvider.list.indexOf(firstDuplicateLayer);
  expect(firstDuplicateLayerIndex, isNonNegative, reason: 'First duplicated mountain layer should exist');
  expect(mountainsLayerIndex, isNonNegative, reason: 'Mountains layer should exist for merge');
  await PaintingLayerHelpers.mergeLayer(session.tester, firstDuplicateLayerIndex, mountainsLayerIndex);

  mountainAppProvider.selectorModel.clear();
  mountainAppProvider.update();
  await session.tester.pump();

  await _setLayerVisibilityByName(session.tester, layerName: _skyLayerName, isVisible: true);
  await session.videoRecorder.captureFrame();
}

Future<void> _duplicateSelectedMountain(
  final PaintingScenarioSession session, {
  required final AppProvider mountainAppProvider,
  required final Offset moveDelta,
  required final double scaleFactor,
}) async {
  mountainAppProvider.selectAll();
  mountainAppProvider.selectedAction = ActionType.selector;
  mountainAppProvider.update();
  await session.tester.pump();

  await mountainAppProvider.regionDuplicate();
  mountainAppProvider.imagePlacementModel.position += moveDelta;
  mountainAppProvider.imagePlacementModel.scale *= scaleFactor;
  mountainAppProvider.update();
  await session.tester.pump();

  await mountainAppProvider.confirmImagePlacement();
  await session.tester.pump();
}
