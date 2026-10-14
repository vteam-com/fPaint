part of '../painting_scenario_test.dart';

// Birds: a small flock crossing the sunset. The flock is drawn level, then
// banked with the transform overlay's Rotate and Scale knobs, plus a few
// distant stragglers.

const String _birdsLayerName = 'Birds';

const Color _birdColor = Color(0xFF22162E);

/// Wing span and wing-beat dip of a bird of scale 1.
const double _birdSpan = 22;
const double _birdDip = 5;
const double _birdLift = 3;

/// (centre, scale, stroke size) per bird.
const List<(Offset, double, double)> _flock = <(Offset, double, double)>[
  (Offset(512, 256), 1.0, 2.2),
  (Offset(546, 238), 0.85, 2),
  (Offset(572, 266), 0.8, 2),
  (Offset(490, 282), 0.7, 1.8),
];
const List<(Offset, double, double)> _stragglers = <(Offset, double, double)>[
  (Offset(700, 214), 0.55, 1.6),
  (Offset(724, 228), 0.45, 1.4),
  (Offset(430, 312), 0.5, 1.4),
];

/// Banking the flock: rotate and scale-up drags on the transform overlay.
const Rect _flockBounds = Rect.fromLTRB(470, 222, 596, 296);
const Offset _flockRotateDrag = Offset(16, 10);
const Offset _flockScaleDrag = Offset(12, 0);

/// One bird as a single "flattened M" stroke: wingtip, dip, body, dip, wingtip.
List<Offset> _birdPoints(Offset center, double scale) {
  final double half = _birdSpan * scale / AppMath.pair;
  return <Offset>[
    center + Offset(-half, -_birdLift * scale),
    center + Offset(-half / AppMath.pair, -_birdDip * scale),
    center,
    center + Offset(half / AppMath.pair, -_birdDip * scale),
    center + Offset(half, -_birdLift * scale),
  ];
}

Future<void> paintShowcaseBirds(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  final AppLocalizations l10n = mainViewContext(tester).l10n;
  await addLayerViaUi(tester, _birdsLayerName);

  await selectPencilTool(tester);
  appProviderFromTester(tester).brushColor = _birdColor;
  for (final (Offset center, double scale, double size) in _flock) {
    await setBrushSizeViaSlider(tester, size);
    await paintCanvasStroke(tester, _birdPoints(center, scale));
  }

  // Bank the flock: marquee it, open the transform overlay, rotate and scale.
  await selectRectangleViaUi(tester, from: _flockBounds.topLeft, to: _flockBounds.bottomRight);
  await tapByTooltip(tester, l10n.transform);
  await pumpForUnitTestUiSettle(tester);
  await dragByTooltip(tester, tooltip: l10n.resizeRotate, delta: _flockRotateDrag);
  await dragByTooltip(tester, tooltip: l10n.scale, delta: _flockScaleDrag);
  await tapByTooltip(tester, l10n.apply);
  await pumpUntilIdle(tester, () => !appProviderFromTester(tester).transformModel.isVisible);
  await clearSelectionViaUi(tester);

  await selectPencilTool(tester);
  for (final (Offset center, double scale, double size) in _stragglers) {
    await setBrushSizeViaSlider(tester, size);
    await paintCanvasStroke(tester, _birdPoints(center, scale));
  }
}
