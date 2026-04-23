part of '../painting_scenario_test.dart';

Future<void> paintLayerClouds(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _cloudsLayerName);

  for (final (Offset center, double radius) in <(Offset, double)>[
    (_cloud1Center, _cloud1Radius),
    (_cloud2Center, _cloud2Radius),
    (_cloud3Center, _cloud3Radius),
    (_cloud4Center, _cloud4Radius),
    (_cloud5Center, _cloud5Radius),
  ]) {
    await drawCircleWithHumanGestures(
      session.tester,
      center: session.canvasCenter + center,
      radius: radius,
      brushSize: 0,
      brushColor: Colors.transparent,
      fillColor: _cloudFillColor,
    );
  }

  final BuildContext cloudContext = session.tester.element(find.byType(MainView));
  final AppProvider cloudAppProvider = AppProvider.of(cloudContext, listen: false);
  expect(cloudAppProvider.layers.selectedLayer.actionStack, isNotEmpty);

  await selectRectangleArea(
    session.tester,
    startPosition: session.canvasCenter + _cloudBottomCutoutStart,
    endPosition: session.canvasCenter + _cloudBottomCutoutEnd,
  );
  expect(cloudAppProvider.selectorModel.path1, isNotNull);

  cloudAppProvider.regionErase();
  await session.tester.pump();

  // Clear the cutout selection so blur applies to the full cloud layer.
  cloudAppProvider.selectorModel.clear();
  cloudAppProvider.update();
  await session.tester.pump();

  // Apply blur effect to soften the clouds.
  await applyEffectViaUi(session.tester, SelectionEffect.blur);

  cloudAppProvider.selectorModel.clear();
  cloudAppProvider.update();
  await session.tester.pump();

  expect(cloudAppProvider.selectorModel.isVisible, isFalse);
  await session.videoRecorder.captureFrame();
}
