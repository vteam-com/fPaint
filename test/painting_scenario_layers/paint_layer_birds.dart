part of '../painting_scenario_test.dart';

Future<void> paintLayerBirds(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _birdsLayerName);

  await _drawBird(
    session.tester,
    canvasCenter: session.canvasCenter,
    topLeftOffset: _bird1Offset,
    scale: _bird1Scale,
    rotationRadians: _bird1RotationRadians,
    brushSize: _bird1BrushSize,
  );

  await _drawBird(
    session.tester,
    canvasCenter: session.canvasCenter,
    topLeftOffset: _bird2Offset,
    scale: _bird2Scale,
    rotationRadians: _bird2RotationRadians,
    brushSize: _bird2BrushSize,
  );

  await _drawBird(
    session.tester,
    canvasCenter: session.canvasCenter,
    topLeftOffset: _bird3Offset,
    scale: _bird3Scale,
    rotationRadians: _bird3RotationRadians,
    brushSize: _bird3BrushSize,
  );
  await session.videoRecorder.captureFrame();
}
