part of '../painting_scenario_test.dart';

Future<void> paintLayerLand(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _landLayerName);

  await drawRectangleWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _landTopLeft,
    endPosition: session.canvasCenter + _landBottomRight,
    brushSize: _landBorderBrushSize,
    brushColor: Colors.greenAccent,
    fillColor: Colors.green,
  );

  await selectRectangleArea(
    session.tester,
    startPosition: session.canvasCenter + _landTopLeft,
    endPosition: session.canvasCenter + _landBottomRight,
  );

  final BuildContext landContext = session.tester.element(find.byType(MainView));
  final AppProvider landAppProvider = AppProvider.of(landContext, listen: false);

  await applyEffectViaUi(
    session.tester,
    SelectionEffect.noise,
    strength: _landNoiseIntensity,
    requireApply: true,
  );

  await pumpForUnitTestUiSettle(session.tester);

  landAppProvider.selectorModel.clear();
  landAppProvider.selectedAction = ActionType.brush;
  landAppProvider.update();
  await pumpForUnitTestUiSettle(session.tester);

  await session.videoRecorder.captureFrame();
}
