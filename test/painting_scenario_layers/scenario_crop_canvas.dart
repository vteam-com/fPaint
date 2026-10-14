part of '../painting_scenario_test.dart';

/// Final framing: trims the edges where strokes were allowed to bleed, keeping
/// the composition centred.
const Size _cropTargetSize = Size(1000, 700);

Future<LayersProvider> cropScenarioCanvas(PaintingScenarioSession session) async {
  final BuildContext context = session.tester.element(find.byType(MainScreen));
  final LayersProvider layersProvider = LayersProvider.of(context);
  final Size preCropCanvasSize = layersProvider.size;
  final int layerCountBeforeCrop = layersProvider.length;

  debugPrint(
    '📐 Cropping canvas: $preCropCanvasSize → '
    '${_cropTargetSize.width.toInt()}x${_cropTargetSize.height.toInt()}',
  );

  await resizeCanvasViaUI(
    session.tester,
    width: _cropTargetSize.width.toInt(),
    height: _cropTargetSize.height.toInt(),
    position: CanvasResizePosition.center,
  );
  await showActualSizeCentered(session.tester);

  expect(layersProvider.size, _cropTargetSize);
  expect(layersProvider.length, layerCountBeforeCrop);
  for (int i = 0; i < layersProvider.length; i++) {
    expect(
      layersProvider.get(i).size,
      _cropTargetSize,
      reason: 'Layer "${layersProvider.get(i).name}" size must match canvas after crop',
    );
  }
  debugPrint(
    '✅ Crop validated: ${layersProvider.size.width.toInt()}x'
    '${layersProvider.size.height.toInt()}, '
    '${layersProvider.length} layers',
  );
  await session.videoRecorder.captureFrame();
  return layersProvider;
}
