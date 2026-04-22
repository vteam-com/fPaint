part of '../painting_scenario_test.dart';

Future<void> paintLayerLand(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _landLayerName);

  await drawRectangleWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _landTopLeft,
    endPosition: session.canvasCenter + _landBottomRight,
    brushSize: AppStroke.thin,
    brushColor: Colors.greenAccent,
    fillColor: Colors.green,
  );
  await session.videoRecorder.captureFrame();
}
