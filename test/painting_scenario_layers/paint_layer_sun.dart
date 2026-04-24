part of '../painting_scenario_test.dart';

Future<void> paintLayerSun(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _sunLayerName);
  final Offset sunCenter = session.canvasCenter + _sunOffset;

  await performFloodFillGradient(
    session.tester,
    gradientMode: FillMode.radial,
    gradientPoints: <GradientPoint>[
      GradientPoint(color: _sunRayColorCenter, offset: Offset(sunCenter.dx / 2, sunCenter.dy)),
      GradientPoint(color: _sunRayColorEdge, offset: sunCenter + const Offset(40, 40)),
    ],
  );
  await session.videoRecorder.captureFrame();

  await drawCircleWithHumanGestures(
    session.tester,
    center: sunCenter,
    radius: _sunRadius,
    brushSize: 0,
    brushColor: Colors.transparent,
    fillColor: _sunBodyColor,
  );
  await session.videoRecorder.captureFrame();

  // Apply soften effect to give the sun a soft edge.
  final BuildContext sunContext = session.tester.element(find.byType(MainView));
  final AppProvider sunAppProvider = AppProvider.of(sunContext, listen: false);
  sunAppProvider.selectAll();
  sunAppProvider.update();
  await session.tester.pump();

  await applyEffectViaUi(session.tester, SelectionEffect.soften, strength: _sunSoftenIntensity);

  sunAppProvider.selectorModel.clear();
  sunAppProvider.update();
  await session.tester.pump();
  await session.videoRecorder.captureFrame();
}
