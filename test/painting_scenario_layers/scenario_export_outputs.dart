part of '../painting_scenario_test.dart';

Future<void> exportScenarioOutputs(PaintingScenarioSession session) async {
  // Export from a 100% view so the rendered finals are pixel-for-pixel crisp.
  await showActualSizeCentered(session.tester);

  await saveUnitTestOraArchive(session.tester, filename: _finalOraFilename);
  await saveUnitTestPng(session.tester, filename: _finalPngFilename);
  await saveUnitTestJpeg(session.tester, filename: _finalJpegFilename);
  await saveUnitTestTiff(session.tester, filename: _finalTiffFilename);
  await saveUnitTestWebp(session.tester, filename: _finalWebpFilename);

  // The coverage exercises that follow expect the fitted view.
  await fitCanvasViaUi(session.tester);
}
