part of '../painting_scenario_test.dart';

// Fence layer
const String _fenceLayerName = 'Fence';
const double _fenceY = 180.0;
const double _fenceHeight = 80.0;
const double _fencePicketSpacing = 100.0;
const double _fenceStartX = -200.0;
const int _fencePicketCount = 6;
const double _fencePicketBrushSize = 10.0;
const double _fencePicketStripeOffset = 4.0;
const Color _fencePicketCenterColor = Color.fromARGB(255, 231, 214, 187);
const Color _fencePicketRightColor = Color.fromARGB(255, 140, 80, 255);
// top rail
Offset _fenceRailTopStart = const Offset(-210, _fenceY - 70);
Offset _fenceRailTopEnd = const Offset(300, _fenceY - 80);
// bottom rail vertical offset from top rail
const double _fenceRailVerticalSpacing = 40.0;

// Fence shadow
const String _fenceShadowLayerName = 'Fence Shadow';
const int _fenceShadowWandTolerance = 48;
final Offset _fenceShadowWandTapOffset = Offset(
  (_fenceRailTopStart.dx + _fenceRailTopEnd.dx) / AppMath.pair,
  (_fenceRailTopStart.dy + _fenceRailTopEnd.dy) / AppMath.pair,
);
const double _fenceShadowGroundOffset = 100.0;
const double _fenceShadowTopHandleDelta = _fenceHeight + _fenceShadowGroundOffset;

Future<void> paintLayerFence(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _fenceLayerName);

  // top fence horizontal rail
  // bottom fence horizontal rail

  for (int i = 0; i < _fencePicketCount; i++) {
    final double picketX = _fenceStartX + (i * _fencePicketSpacing);
    for (final (double offsetX, Color color) in <(double, Color)>[
      (-_fencePicketStripeOffset, Colors.white),
      (_fencePicketStripeOffset, _fencePicketRightColor),
      (0, _fencePicketCenterColor),
    ]) {
      await drawLineWithHumanGestures(
        session.tester,
        startPosition: session.canvasCenter + Offset(picketX + offsetX, _fenceY),
        endPosition: session.canvasCenter + Offset(picketX + offsetX, _fenceY - _fenceHeight),
        brushSize: _fencePicketBrushSize,
        brushColor: color,
      );
    }
  }

  await drawRectangleWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _fenceRailTopStart,
    endPosition: session.canvasCenter + _fenceRailTopEnd,
    brushSize: AppStroke.thin,
    brushColor: Colors.grey,
    fillColor: _fencePicketCenterColor,
  );
  await drawRectangleWithHumanGestures(
    session.tester,
    startPosition: session.canvasCenter + _fenceRailTopStart + const Offset(0, _fenceRailVerticalSpacing),
    endPosition: session.canvasCenter + _fenceRailTopEnd + const Offset(0, _fenceRailVerticalSpacing),
    brushSize: AppStroke.thin,
    brushColor: Colors.grey,
    fillColor: _fencePicketCenterColor,
  );
  await session.videoRecorder.captureFrame();
}

Future<void> paintLayerFenceShadow(final PaintingScenarioSession session) async {
  // While still on the fence layer, select the fence silhouette with the magic
  // wand at high tolerance so every picket and rail is captured.
  // Anchor the wand on the tan top rail instead of the purple side stripe so
  // the selection stays on the fence silhouette and does not bleed into the
  // similarly colored background.
  await selectWandArea(
    session.tester,
    position: session.canvasCenter + _fenceShadowWandTapOffset,
    tolerance: _fenceShadowWandTolerance,
  );

  // Add the shadow layer — the wand selection is preserved across layer changes.
  await PaintingLayerHelpers.addNewLayer(session.tester, _fenceShadowLayerName);

  // Fill the shadow layer with a semi-transparent purple.  The empty layer
  // makes the flood fill spread everywhere, but recordExecuteDrawingActionToSelectedLayer
  // clips the stored action to selectorModel.path1 (the fence wand path) so
  // only the fence silhouette is painted.
  await performFloodFillSolid(
    session.tester,
    position: session.canvasCenter + _fenceShadowWandTapOffset,
    color: _shadowColor,
    tolerance: _fenceShadowWandTolerance,
  );

  // Reactivate the selector tool so the transform overlay is accessible.
  await tapByKey(session.tester, Keys.toolSelector);
  await session.tester.pump();

  // Skew: drag both top handles down so the tip of the shadow lands
  // _fenceShadowGroundOffset px below the fence base — casting it on the ground.
  await deformSelectionWithTransformOverlay(
    session.tester,
    handleDeltas: <TransformOverlayHandle, Offset>{
      TransformOverlayHandle.topLeft: const Offset(20, _fenceShadowTopHandleDelta),
      TransformOverlayHandle.topRight: const Offset(30, _fenceShadowTopHandleDelta),
    },
  );

  // Dismiss selection.
  final BuildContext context = session.tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  appProvider.selectorModel.clear();
  appProvider.update();
  await session.tester.pump();
  await session.videoRecorder.captureFrame();
}
