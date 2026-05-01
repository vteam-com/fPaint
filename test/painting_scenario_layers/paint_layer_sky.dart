part of '../painting_scenario_test.dart';

Future<void> paintLayerSky(final PaintingScenarioSession session) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _skyLayerName);
  // Four-stop linear gradient with 3 distinct shades of blue:
  //   0%  – deep navy at the zenith
  //  25%  – royal blue (upper-sky)
  //  60%  – medium sky blue (mid-sky)
  // 100%  – pale horizon blue
  await performFloodFillGradient(
    session.tester,
    gradientMode: FillMode.linear,
    gradientPoints: <GradientPoint>[
      GradientPoint(color: _skyColorTop, offset: session.canvasCenter + _skyGradientTop),
      GradientPoint(color: _skyColorUpperMid, offset: session.canvasCenter + _skyGradientTop),
      GradientPoint(color: _skyColorLowerMid, offset: session.canvasCenter + _skyGradientTop),
      GradientPoint(color: _skyColorBottom, offset: session.canvasCenter + _skyGradientBottom),
    ],
    gradientStopPositions: <double>[0.0, _skyUpperMidStopPosition, _skyLowerMidStopPosition, 1.0],
  );
  await session.videoRecorder.captureFrame();
}
