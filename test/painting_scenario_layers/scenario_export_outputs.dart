part of '../painting_scenario_test.dart';

Future<void> exportScenarioOutputs(final PaintingScenarioSession session) async {
  await saveUnitTestOraArchive(session.tester, filename: _finalOraFilename);
  await saveUnitTestPng(session.tester, filename: _finalPngFilename);
  await saveUnitTestJpeg(session.tester, filename: _finalJpegFilename);
  await saveUnitTestTiff(session.tester, filename: _finalTiffFilename);
  await saveUnitTestWebp(session.tester, filename: _finalWebpFilename);
}
