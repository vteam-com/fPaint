part of '../painting_scenario_test.dart';

Future<void> paintLayerHouse(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _houseLayerName);

  await drawRectangleWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _houseBodyStart,
    endPosition: session.canvasCenter + _houseBodyEnd,
    brushSize: AppStroke.thin,
    brushColor: Colors.white,
    fillColor: const Color.fromARGB(255, 248, 163, 191),
  );

  await drawRectangleWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _houseDoorStart,
    endPosition: session.canvasCenter + _houseDoorEnd,
    brushSize: AppStroke.regular,
    brushColor: Colors.white,
    fillColor: Colors.red,
  );

  await drawRectangleWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _houseWindowStart,
    endPosition: session.canvasCenter + _houseWindowEnd,
    brushSize: AppStroke.regular,
    brushColor: Colors.white,
    fillColor: Colors.grey,
  );

  await drawLineWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _roofLeft,
    endPosition: session.canvasCenter + _roofPeak,
    brushSize: AppStroke.regular,
    brushColor: Colors.orange,
  );
  await drawLineWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _roofRight,
    endPosition: session.canvasCenter + _roofPeak,
    brushSize: AppStroke.regular,
    brushColor: Colors.orange,
  );
  await drawLineWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _roofLeft,
    endPosition: session.canvasCenter + _roofRight,
    brushSize: AppStroke.regular,
    brushColor: Colors.orange,
  );

  await performFloodFillSolidAtCanvasPosition(
    session.tester,
    canvasPosition: _roofFillCanvasPosition,
    color: _roofFillColor,
    tolerance: 0,
  );
  await session.videoRecorder.captureFrame();
}
