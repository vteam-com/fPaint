part of '../painting_scenario_test.dart';

Future<void> applyPostCropVignette(final PaintingScenarioSession session) async {
  final BuildContext context = session.tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  appProvider.selectAll();
  appProvider.update();
  await session.tester.pump();

  await applyEffectViaUi(
    session.tester,
    SelectionEffect.vignette,
    strength: _vignetteIntensity,
  );

  appProvider.selectorModel.clear();
  appProvider.update();
  await session.tester.pump();
  await session.videoRecorder.captureFrame();
}
