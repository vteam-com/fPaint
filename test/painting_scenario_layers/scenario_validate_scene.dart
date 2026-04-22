part of '../painting_scenario_test.dart';

Future<void> validateScenarioScene(
  final PaintingScenarioSession session, {
  required final LayersProvider layersProvider,
}) async {
  await PaintingLayerHelpers.printLayerStructure(session.tester);

  expect(
    layersProvider.length,
    _expectedLayerCountAfterScene,
    reason:
        'Should have background + sky + mountains + clouds + sun + land + shadows + house + fence shadow + fence + birds + signature',
  );

  expect(
    layersProvider.list.map((final LayerProvider layer) => layer.name).toList(),
    <String>[
      _signatureLayerName,
      _birdsLayerName,
      _fenceShadowLayerName,
      _fenceLayerName,
      _houseLayerName,
      _shadowsLayerName,
      _landLayerName,
      _sunLayerName,
      _cloudsLayerName,
      _mountainsLayerName,
      _skyLayerName,
      _backgroundLayerName,
    ],
  );
}
