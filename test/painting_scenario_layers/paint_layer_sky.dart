part of '../painting_scenario_test.dart';

Future<void> paintLayerSky(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _skyLayerName);
  await performFloodFillGradient(
    session.tester,
    gradientMode: FillMode.linear,
    gradientPoints: <GradientPoint>[
      GradientPoint(color: _skyColorTop, offset: session.canvasCenter + _skyGradientTop),
      GradientPoint(color: _skyColorBottom, offset: session.canvasCenter + _skyGradientBottom),
    ],
  );
  await session.videoRecorder.captureFrame();
}
