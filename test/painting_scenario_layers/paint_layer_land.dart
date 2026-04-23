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

  // Select the land area with a small margin to cover border edges,
  // then repeat noise + pixelation for distortion,
  // followed by a final blur for a natural grass texture.
  await selectRectangleArea(
    session.tester,
    startPosition: session.canvasCenter + _landTopLeft - const Offset(_landSelectionMargin, _landSelectionMargin),
    endPosition: session.canvasCenter + _landBottomRight + const Offset(_landSelectionMargin, _landSelectionMargin),
  );

  for (int i = 0; i < _landGrassDistortionPasses; i++) {
    await applyEffectViaUi(session.tester, SelectionEffect.noise);
    await applyEffectViaUi(session.tester, SelectionEffect.pixelate);
  }
  await applyEffectViaUi(session.tester, SelectionEffect.blur);
  await applyEffectViaUi(session.tester, SelectionEffect.noise);

  final BuildContext landContext = session.tester.element(find.byType(MainView));
  final AppProvider landAppProvider = AppProvider.of(landContext, listen: false);
  landAppProvider.selectorModel.clear();
  landAppProvider.update();
  await session.tester.pump();

  await session.videoRecorder.captureFrame();
}
