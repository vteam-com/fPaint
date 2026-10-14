part of '../painting_scenario_test.dart';

// Vignette: a painter's vignette — a radial gradient from clear to deep violet
// on its own layer, multiplied over the scene to draw the eye to the sun.

const String _vignetteLayerName = 'Vignette';

const Offset _vignetteCenter = Offset(_sceneWidth / AppMath.pair, _sceneHeight / AppMath.pair);

/// Centre-to-corner distance of the 1024 × 768 scene.
const double _vignetteRadius = 640;
const List<Color> _vignetteColors = <Color>[Color(0x000A0618), Color(0x000A0618), Color(0xB40A0618)];
const List<double> _vignetteStops = <double>[0, 0.55, 1];

Future<void> paintShowcaseVignette(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  final AppLocalizations l10n = mainViewContext(tester).l10n;
  await addLayerViaUi(tester, _vignetteLayerName);
  await gradientFillViaUi(
    tester,
    mode: FillMode.radial,
    tapPoint: _vignetteCenter,
    start: _vignetteCenter,
    end: _vignetteCenter + const Offset(_vignetteRadius, 0),
    colors: _vignetteColors,
    stops: _vignetteStops,
  );
  await setSelectedLayerBlendModeViaUi(
    tester,
    blendMode: BlendMode.multiply,
    description: l10n.blendModeMultiplyDescription,
  );
}
