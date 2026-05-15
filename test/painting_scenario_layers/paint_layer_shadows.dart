part of '../painting_scenario_test.dart';

Future<void> paintLayerHouseShadow(final PaintingScenarioSession session) async {
  // Ensure we are on the House layer before wand-selecting.
  await PaintingLayerHelpers.switchToLayerByName(session.tester, _houseLayerName);

  // Select the house silhouette with the magic wand at full tolerance
  // so the entire house is captured.
  await selectWandArea(
    session.tester,
    position: session.canvasCenter + _houseShadowWandTapOffset,
    tolerance: _houseShadowWandTolerance,
  );

  // Add the house shadow layer — the wand selection is preserved across layer changes.
  await PaintingLayerHelpers.addNewLayer(session.tester, _houseShadowLayerName);

  // Fill the shadow layer with a semi-transparent purple.  The empty layer
  // makes the flood fill spread everywhere, but recordExecuteDrawingActionToSelectedLayer
  // clips the stored action to selectorModel.path1 (the house wand path) so
  // only the house silhouette is painted.
  await performFloodFillSolid(
    session.tester,
    position: session.canvasCenter,
    color: _shadowColor,
    tolerance: _houseShadowWandTolerance,
  );

  // Reactivate the selector tool so the transform overlay is accessible.
  await tapByKey(session.tester, Keys.toolSelector);
  await session.tester.pump();

  // Match the previous straight-edge projection by moving the top boundary and
  // re-centering the side edge midpoints onto the old bilinear edge lines.
  await deformSelectionWithTransformOverlay(
    session.tester,
    handleDeltas: <TransformOverlayHandle, Offset>{
      TransformOverlayHandle.topLeft: const Offset(
        _houseShadowTopLeftHandleXDelta,
        _houseShadowTopHandleDelta,
      ),
      TransformOverlayHandle.top: const Offset(
        _houseShadowTopEdgeHandleXDelta,
        _houseShadowTopHandleDelta,
      ),
      TransformOverlayHandle.topRight: const Offset(
        _houseShadowTopRightHandleXDelta,
        _houseShadowTopHandleDelta,
      ),
      TransformOverlayHandle.right: const Offset(
        _houseShadowRightEdgeHandleXDelta,
        _houseShadowSideEdgeHandleYDelta,
      ),
      TransformOverlayHandle.left: const Offset(
        _houseShadowLeftEdgeHandleXDelta,
        _houseShadowSideEdgeHandleYDelta,
      ),
    },
  );

  // Dismiss selection.
  final BuildContext context = session.tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  appProvider.selectorModel.clear();
  appProvider.update();
  await session.tester.pump();
  await session.videoRecorder.captureFrame();

  // Move the house shadow layer below the house layer.
  final LayersProvider layersProvider = LayersProvider.of(context);
  final LayerProvider shadowLayer = layersProvider.list.firstWhere(
    (final LayerProvider layer) => layer.name == _houseShadowLayerName,
  );
  layersProvider.remove(shadowLayer);
  final int houseIdx = layersProvider.list.indexWhere(
    (final LayerProvider layer) => layer.name == _houseLayerName,
  );
  layersProvider.insert(houseIdx + 1, shadowLayer);
  layersProvider.selectedLayerIndex = layersProvider.getLayerIndex(shadowLayer);
  layersProvider.update();
  await session.tester.pump();

  // Switch back to the House layer so subsequent layers are inserted above it.
  await PaintingLayerHelpers.switchToLayerByName(session.tester, _houseLayerName);
}
