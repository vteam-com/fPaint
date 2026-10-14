part of '../painting_scenario_test.dart';

// Mist: soft pink haze pooled at the foot of the mountains, blurred with the
// Blur effect brush and faded with the layer-opacity scrub.

const String _mistLayerName = 'Mist';

const Color _mistColor = Color(0x5CFFD8E6);
const double _mistSize = 44;
const double _mistHighSize = 26;
const List<List<Offset>> _mistBands = <List<Offset>>[
  <Offset>[Offset(-20, 452), Offset(260, 446), Offset(520, 456), Offset(780, 448), Offset(1044, 454)],
  <Offset>[Offset(-20, 432), Offset(200, 438), Offset(420, 430)],
  <Offset>[Offset(700, 436), Offset(880, 428), Offset(1044, 434)],
];
const List<List<Offset>> _mistHighBands = <List<Offset>>[
  <Offset>[Offset(-20, 404), Offset(120, 398), Offset(260, 408), Offset(380, 402)],
  <Offset>[Offset(760, 400), Offset(900, 392), Offset(1044, 398)],
];
const double _mistBlurSize = 70;
const double _mistBlurIntensity = 0.6;
const double _mistOpacity = 0.7;

/// A subtle warm hue drift over the whole mist layer.
const double _mistHueStrength = 0.06;

Future<void> paintShowcaseMist(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  await addLayerViaUi(tester, _mistLayerName);

  await selectBrushTool(tester);
  await selectBrushStyleViaUi(tester, BrushStyle.soft);
  await pickBrushColorViaUi(tester, _mistColor);
  await setBrushSizeViaSlider(tester, _mistSize);
  for (final List<Offset> band in _mistBands) {
    await paintCanvasStroke(tester, band);
  }
  await setBrushSizeViaSlider(tester, _mistHighSize);
  for (final List<Offset> band in _mistHighBands) {
    await paintCanvasStroke(tester, band);
  }

  await armEffectBrushViaUi(tester, SelectionEffect.blur, strength: _mistBlurIntensity, brushSize: _mistBlurSize);
  await paintCanvasStroke(tester, _mistBands.first);

  await disarmEffectBrushViaUi(tester);
  await applyEffectViaUi(tester, SelectionEffect.hueRotation, strength: _mistHueStrength, requireApply: true);
  await clearSelectionViaUi(tester);

  await setLayerOpacityViaUi(tester, layerName: _mistLayerName, opacity: _mistOpacity);
}
