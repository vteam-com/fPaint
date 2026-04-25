part of '../painting_scenario_test.dart';

Future<void> paintLayerHouse(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _houseLayerName);

  // Draw house body, door, and window first.
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

  // Draw converging roof stripes on top of the house body so they are visible.
  const double baseWidth = _roofBaseRight - _roofBaseLeft;
  const double topWidth = _roofTopRight - _roofTopLeft;

  for (int i = 0; i < _roofStripeCount; i++) {
    final double t = i / (_roofStripeCount - 1);
    final double bottomX = _roofBaseLeft + t * baseWidth;
    final double topX = _roofTopLeft + t * topWidth;
    final Color color = i.isEven
        ? const ui.Color.fromARGB(255, 206, 169, 75)
        : const ui.Color.fromARGB(255, 177, 139, 63);

    await drawLineWithHumanGestures(
      session.tester,
      startPosition: session.canvasCenter + Offset(bottomX, _roofBaseY),
      endPosition: session.canvasCenter + Offset(topX, _roofTopY),
      brushSize: _roofStripeBrushSize,
      brushColor: color,
    );
  }

  await session.videoRecorder.captureFrame();
}
