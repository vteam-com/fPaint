part of '../painting_scenario_test.dart';

Future<LayersProvider> cropScenarioCanvas(final PaintingScenarioSession session) async {
  final BuildContext context = session.tester.element(find.byType(MainScreen));
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
    session.tester,
    width: cropTargetSize.width.toInt(),
    height: cropTargetSize.height.toInt(),
    position: CanvasResizePosition.top,
  );
  await prepareCanvasViewport(session.tester);
  await pumpForUnitTestUiSettle(session.tester);

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
  await session.videoRecorder.captureFrame();
  return layersProvider;
}
