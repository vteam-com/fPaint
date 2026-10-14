part of '../painting_scenario_test.dart';

Future<void> validateScenarioScene(
  PaintingScenarioSession session, {
  required LayersProvider layersProvider,
}) async {
  await PaintingLayerHelpers.printLayerStructure(session.tester);

  expect(
    layersProvider.list.map((LayerProvider layer) => layer.name).toList(),
    _expectedSceneLayerNames,
    reason: 'The finished showcase should have exactly the expected layer stack',
  );
  expect(layersProvider.length, _expectedLayerCountAfterScene);

  // Every layer that holds paint should have visible content.
  for (final LayerProvider layer in layersProvider.list) {
    if (layer.name == _backgroundLayerName) {
      continue;
    }
    expect(layer.actionStack, isNotEmpty, reason: 'Layer "${layer.name}" should hold paint');
  }
}
