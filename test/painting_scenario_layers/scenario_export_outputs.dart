part of '../painting_scenario_test.dart';

Future<void> exportScenarioOutputs(final PaintingScenarioSession session) async {
  await saveUnitTestArtworkViaExportUi(
    session.tester,
    format: UnitTestExportFormat.ora,
    filename: _finalOraFilename,
  );

  await saveUnitTestArtworkViaExportUi(
    session.tester,
    format: UnitTestExportFormat.png,
    filename: _finalPngFilename,
  );

  await saveUnitTestArtworkViaExportUi(
    session.tester,
    format: UnitTestExportFormat.jpeg,
    filename: _finalJpegFilename,
  );

  await saveUnitTestArtworkViaExportUi(
    session.tester,
    format: UnitTestExportFormat.tiff,
    filename: _finalTiffFilename,
  );

  await saveUnitTestArtworkViaExportUi(
    session.tester,
    format: UnitTestExportFormat.webp,
    filename: _finalWebpFilename,
  );
  await dismissOpenUnitTestExportSheet(session.tester);
}
