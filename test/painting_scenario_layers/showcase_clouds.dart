part of '../painting_scenario_test.dart';

// Clouds: long altostratus bands blocked in with the Soft brush, lit from
// below by the low sun, then pulled together with the Smudge tool and the Blur
// effect brush — the classic "block in, then blend" workflow.

const String _cloudsLayerName = 'Clouds';

/// One cloud band: a gentle wave from [from] to [to].
typedef _CloudBand = ({Offset from, Offset to, double amplitude, double size});

const List<_CloudBand> _cloudBodies = <_CloudBand>[
  (from: Offset(-20, 116), to: Offset(470, 100), amplitude: 7, size: 30),
  (from: Offset(320, 152), to: Offset(1040, 136), amplitude: 6, size: 34),
  (from: Offset(-20, 206), to: Offset(430, 218), amplitude: 8, size: 26),
  (from: Offset(690, 196), to: Offset(1040, 206), amplitude: 6, size: 28),
  (from: Offset(370, 268), to: Offset(560, 260), amplitude: 4, size: 14),
  (from: Offset(670, 252), to: Offset(910, 262), amplitude: 4, size: 16),
];

/// Offset of the lit underside / gold rim below each band's centre line.
const double _cloudUndersideDrop = 11;
const double _cloudRimDrop = 17;
const double _cloudUndersideSizeRatio = 0.45;
const double _cloudRimSize = 4;

const Color _cloudBodyColor = Color(0xB45B3B7A);
const Color _cloudRimColor = Color(0xD8FFD68F);

/// Where the eyedropper samples the warm sky for the lit undersides.
const Offset _cloudUndersideSample = Offset(260, 400);

/// Bands whose centre lies within this distance of the sun get a gold rim.
const double _cloudRimReach = 330;

/// Smudge passes that drag each band sideways, as wind would.
const double _cloudSmudgeSize = 34;
const double _cloudSmudgeIntensity = 0.65;
const double _cloudSmudgeLength = 90;
const double _cloudSmudgeLift = 4;

/// Blur effect-brush passes that push the farthest clouds back.
const double _cloudBlurSize = 56;
const double _cloudBlurIntensity = 0.55;
const List<List<Offset>> _cloudBlurStrokes = <List<Offset>>[
  <Offset>[Offset(0, 112), Offset(160, 108), Offset(320, 104), Offset(460, 102)],
  <Offset>[Offset(0, 210), Offset(140, 214), Offset(280, 216), Offset(420, 218)],
];

Future<void> paintShowcaseClouds(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  await addLayerViaUi(tester, _cloudsLayerName);

  // Block in the dark bodies with the soft brush.
  await selectBrushTool(tester);
  await selectBrushStyleViaUi(tester, BrushStyle.soft);
  await pickBrushColorViaUi(tester, _cloudBodyColor);
  for (final _CloudBand band in _cloudBodies) {
    await setBrushSizeViaSlider(tester, band.size);
    await paintCanvasStroke(tester, _wavePoints(band.from, band.to, amplitude: band.amplitude));
  }

  // Lit undersides: borrow the ember orange straight from the sky.
  await eyedropBrushColorViaUi(tester, _cloudUndersideSample);
  for (final _CloudBand band in _cloudBodies) {
    await setBrushSizeViaSlider(tester, band.size * _cloudUndersideSizeRatio);
    await paintCanvasStroke(
      tester,
      _wavePoints(
        band.from + const Offset(0, _cloudUndersideDrop),
        band.to + const Offset(0, _cloudUndersideDrop),
        amplitude: band.amplitude,
      ),
    );
  }

  // Gold rims on the bands nearest the sun.
  appProviderFromTester(tester).brushColor = _cloudRimColor;
  await setBrushSizeViaSlider(tester, _cloudRimSize);
  for (final _CloudBand band in _cloudBodies) {
    final Offset middle = Offset.lerp(band.from, band.to, AppVisual.half)!;
    if ((middle - _sunCenter).distance > _cloudRimReach) {
      continue;
    }
    await paintCanvasStroke(
      tester,
      _wavePoints(
        band.from + const Offset(0, _cloudRimDrop),
        band.to + const Offset(0, _cloudRimDrop),
        amplitude: band.amplitude,
      ),
    );
  }

  // Blend: smudge each band downwind. More than the history cap of smudge
  // gestures lands on this layer, so it also exercises history compaction.
  await selectToolByKey(tester, Keys.toolSmudge);
  await setBrushSizeViaSlider(tester, _cloudSmudgeSize);
  await setBrushIntensityViaPicker(tester, _cloudSmudgeIntensity);
  for (final _CloudBand band in _cloudBodies) {
    final Offset start = Offset.lerp(band.from, band.to, AppVisual.half)!;
    await paintCanvasStroke(
      tester,
      _wavePoints(
        start,
        start + const Offset(_cloudSmudgeLength, -_cloudSmudgeLift),
        amplitude: _cloudSmudgeLift,
        samples: _waveSamples ~/ AppMath.pair,
      ),
    );
  }

  // Push the far-left clouds back by painting the Blur effect as a brush.
  await armEffectBrushViaUi(tester, SelectionEffect.blur, strength: _cloudBlurIntensity, brushSize: _cloudBlurSize);
  for (final List<Offset> stroke in _cloudBlurStrokes) {
    await paintCanvasStroke(tester, stroke);
  }
  await disarmEffectBrushViaUi(tester);
}
