part of '../painting_scenario_test.dart';

Future<void> paintLayerHouse(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _houseLayerName);

  final BuildContext context = session.tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  final Offset canvasCenter = Offset(
    appProvider.layers.width / AppMath.pair,
    appProvider.layers.height / AppMath.pair,
  );
  final Rect houseBodyRect = Rect.fromPoints(
    canvasCenter + _houseBodyStart,
    canvasCenter + _houseBodyEnd,
  );

  appProvider.recordExecuteDrawingActionToSelectedLayer(
    action: UserActionDrawing(
      action: ActionType.region,
      positions: <ui.Offset>[houseBodyRect.topLeft, houseBodyRect.bottomRight],
      fillColor: _houseBodyHalftoneBackgroundColor,
      halftoneFill: const HalftoneFill(
        backgroundColor: _houseBodyHalftoneBackgroundColor,
        dotColor: _houseBodyHalftoneDotColor,
        maxDotSizeFactor: _houseBodyHalftoneMaxDotSizeFactor,
      ),
      path: Path()..addRect(houseBodyRect),
    ),
  );
  await session.tester.pump();

  // Draw house outline, door, and window on top of the halftone body.
  await drawRectangleWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _houseBodyStart,
    endPosition: session.canvasCenter + _houseBodyEnd,
    brushSize: AppStroke.thin,
    brushColor: Colors.white,
    fillColor: Colors.transparent,
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
