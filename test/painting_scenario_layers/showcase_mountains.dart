part of '../painting_scenario_test.dart';

// Mountains: a hazy far range for depth, then two sharp peaks catching the
// alpenglow. Lit faces and snow are painted on a scratch layer (so each fill is
// a clean region) and merged down; texture, smudged snowlines and effect
// brushes finish the rock before the peaks merge into the far range.

const String _mountainsLayerName = 'Mountains';
const String _farRangeLayerName = 'Far Range';
const String _peaksLayerName = 'Peaks';
const String _alpenglowLayerName = 'Alpenglow';

// --- Far range --------------------------------------------------------------

const double _farRidgeBaseY = 364;
const double _farRidgeStep = 26;
const double _farRidgeSlowAmplitude = 20;
const double _farRidgeSlowWavelength = 70;
const double _farRidgeFastAmplitude = 9;
const double _farRidgeFastWavelength = 19;
const double _farRidgeFastPhase = 1.3;

/// The ridge dips around the sun so it sits in a notch.
const double _farRidgeNotchDepth = 26;
const double _farRidgeNotchWidth = 95;
const double _farRidgeFootY = _waterlineY + 24;

const List<Color> _farRangeColors = <Color>[Color(0xFF8E6FB0), Color(0xFFD493A8)];
const List<double> _twoStops = <double>[0, 1];
const Offset _farRangeGradientStart = Offset(_sceneWidth / AppMath.pair, 330);
const Offset _farRangeGradientEnd = Offset(_sceneWidth / AppMath.pair, _waterlineY);
const Offset _farRangeTap = Offset(140, 430);
const double _farRangeBlurStrength = 0.22;

List<Offset> _farRidgeOutline() {
  final List<Offset> ridge = <Offset>[];
  for (double x = -_edgeBleed; x <= _sceneWidth + _edgeBleed; x += _farRidgeStep) {
    final double notch = math.exp(-math.pow((x - _sunCenter.dx) / _farRidgeNotchWidth, AppMath.pair).toDouble());
    ridge.add(
      Offset(
        x,
        _farRidgeBaseY +
            _farRidgeSlowAmplitude * math.sin(x / _farRidgeSlowWavelength) +
            _farRidgeFastAmplitude * math.sin(x / _farRidgeFastWavelength + _farRidgeFastPhase) +
            _farRidgeNotchDepth * notch,
      ),
    );
  }
  return <Offset>[
    ...ridge,
    const Offset(_sceneWidth + _edgeBleed, _farRidgeFootY),
    const Offset(-_edgeBleed, _farRidgeFootY),
  ];
}

// --- Main peaks ---------------------------------------------------------------

const List<Offset> _peakWestOutline = <Offset>[
  Offset(-12, 494), Offset(-12, 352), Offset(30, 338), Offset(70, 352), Offset(105, 330), //
  Offset(150, 318), Offset(185, 282), Offset(215, 262), Offset(240, 238), Offset(262, 214),
  Offset(285, 196), Offset(304, 182), Offset(318, 170), Offset(330, 158), Offset(342, 168),
  Offset(356, 186), Offset(372, 200), Offset(392, 226), Offset(410, 246), Offset(432, 276),
  Offset(458, 300), Offset(486, 330), Offset(516, 356), Offset(548, 382), Offset(580, 410),
  Offset(612, 440), Offset(640, 494),
];

const List<Offset> _peakEastOutline = <Offset>[
  Offset(600, 494), Offset(640, 452), Offset(676, 420), Offset(706, 388), Offset(732, 352), //
  Offset(756, 322), Offset(780, 292), Offset(800, 268), Offset(816, 246), Offset(832, 226),
  Offset(848, 208), Offset(862, 222), Offset(878, 240), Offset(900, 262), Offset(926, 284),
  Offset(956, 300), Offset(990, 318), Offset(1036, 330), Offset(1036, 494),
];

const List<Color> _peakBodyColors = <Color>[Color(0xFF4B4380), Color(0xFF29274C)];
const Offset _peakBodyGradientStart = Offset(_sceneWidth / AppMath.pair, 160);
const Offset _peakBodyGradientEnd = Offset(_sceneWidth / AppMath.pair, _waterlineY);
const Offset _peakWestTap = Offset(250, 400);
const Offset _peakEastTap = Offset(880, 400);

/// Sun-facing slopes: the west peak's east face and the east peak's west face.
const List<Offset> _peakWestLitFace = <Offset>[
  Offset(330, 158), Offset(342, 168), Offset(356, 186), Offset(372, 200), Offset(392, 226), //
  Offset(410, 246), Offset(432, 276), Offset(458, 300), Offset(486, 330), Offset(516, 356),
  Offset(548, 382), Offset(520, 400), Offset(480, 384), Offset(452, 360), Offset(430, 340),
  Offset(408, 312), Offset(392, 290), Offset(372, 262), Offset(360, 236), Offset(348, 206),
  Offset(338, 184),
];
const List<Offset> _peakEastLitFace = <Offset>[
  Offset(848, 208), Offset(832, 226), Offset(816, 246), Offset(800, 268), Offset(780, 292), //
  Offset(756, 322), Offset(732, 352), Offset(706, 388), Offset(676, 420), Offset(700, 432),
  Offset(736, 410), Offset(766, 380), Offset(790, 350), Offset(810, 318), Offset(826, 286),
  Offset(838, 256), Offset(844, 230),
];
const List<Color> _alpenglowColors = <Color>[Color(0xFFF7B48C), Color(0xFFC0697A), Color(0xFF7A3F72)];
const List<double> _alpenglowStops = <double>[0, 0.45, 1];
const Offset _peakWestLitTap = Offset(420, 300);
const Offset _peakWestLitEnd = Offset(480, 400);
const Offset _peakEastLitTap = Offset(770, 360);
const Offset _peakEastLitEnd = Offset(700, 430);

/// Snow caps, lit on the sun side and lavender in shade.
const List<Offset> _snowWest = <Offset>[
  Offset(300, 186), Offset(318, 170), Offset(330, 158), Offset(342, 168), Offset(356, 186), //
  Offset(368, 200), Offset(356, 206), Offset(346, 196), Offset(338, 214), Offset(328, 198),
  Offset(318, 210), Offset(310, 198), Offset(296, 204),
];
const List<Offset> _snowEast = <Offset>[
  Offset(826, 236), Offset(838, 220), Offset(848, 208), Offset(862, 222), Offset(878, 240), //
  Offset(870, 246), Offset(860, 236), Offset(852, 254), Offset(844, 240), Offset(834, 250),
];
const Color _snowShadeColor = Color(0xFFB8A6DE);
const Color _snowLitColor = Color(0xFFFFEADF);
const Offset _snowWestTap = Offset(330, 180);
const Offset _snowEastTap = Offset(850, 226);

// --- Rock detail --------------------------------------------------------------

const Color _rockTextureColor = Color(0x66231E3C);
const double _rockTextureSize = 22;
const List<List<Offset>> _rockTextureStrokes = <List<Offset>>[
  <Offset>[Offset(150, 360), Offset(200, 320), Offset(250, 280), Offset(290, 240)],
  <Offset>[Offset(90, 400), Offset(160, 380), Offset(230, 360), Offset(300, 330)],
  <Offset>[Offset(890, 300), Offset(930, 330), Offset(980, 350), Offset(1030, 360)],
  <Offset>[Offset(860, 260), Offset(890, 320), Offset(920, 380), Offset(950, 430)],
];

const Color _couloirColor = Color(0xB0201A38);
const double _couloirSize = 1.6;
const List<List<Offset>> _couloirStrokes = <List<Offset>>[
  <Offset>[Offset(318, 214), Offset(300, 250), Offset(286, 290), Offset(268, 330)],
  <Offset>[Offset(300, 214), Offset(272, 240), Offset(246, 268), Offset(222, 300)],
  <Offset>[Offset(342, 214), Offset(352, 260), Offset(366, 300), Offset(386, 340)],
  <Offset>[Offset(864, 252), Offset(880, 290), Offset(900, 330), Offset(926, 362)],
  <Offset>[Offset(846, 256), Offset(838, 300), Offset(826, 340), Offset(806, 390)],
];

const Color _ridgeLightColor = Color(0xE6FFD6B5);
const double _ridgeLightSize = 2;
const List<Offset> _peakWestLitRidge = <Offset>[
  Offset(330, 159),
  Offset(342, 169),
  Offset(356, 187),
  Offset(372, 201),
  Offset(392, 227),
  Offset(410, 247),
];
const List<Offset> _peakEastLitRidge = <Offset>[
  Offset(848, 209),
  Offset(832, 227),
  Offset(816, 247),
  Offset(800, 269),
  Offset(780, 293),
  Offset(756, 323),
];

/// Short smudges that drag snow down into the rock.
const double _snowlineSmudgeSize = 12;
const double _snowlineSmudgeIntensity = 0.55;
const List<List<Offset>> _snowlineSmudges = <List<Offset>>[
  <Offset>[Offset(318, 206), Offset(316, 216), Offset(313, 228), Offset(311, 238)],
  <Offset>[Offset(346, 200), Offset(349, 212), Offset(352, 224), Offset(355, 234)],
  <Offset>[Offset(842, 242), Offset(840, 252), Offset(838, 262), Offset(836, 272)],
  <Offset>[Offset(862, 236), Offset(865, 246), Offset(868, 256), Offset(871, 266)],
];

/// Effect-brush passes: light the ridges, enrich the glow, crisp the snow.
const double _ridgeBrightnessStrength = 0.3;
const double _ridgeBrightnessSize = 18;
const double _glowSaturationStrength = 0.35;
const double _glowSaturationSize = 70;
const double _snowSharpnessStrength = 0.6;
const double _snowSharpnessSize = 40;
const List<List<Offset>> _glowSaturationStrokes = <List<Offset>>[
  <Offset>[Offset(350, 210), Offset(400, 270), Offset(450, 320), Offset(500, 370)],
  <Offset>[Offset(830, 250), Offset(790, 300), Offset(750, 350), Offset(710, 400)],
];
const List<List<Offset>> _snowSharpnessStrokes = <List<Offset>>[
  <Offset>[Offset(300, 190), Offset(330, 180), Offset(366, 196)],
  <Offset>[Offset(828, 236), Offset(850, 222), Offset(876, 240)],
];

Future<void> paintShowcaseMountains(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;

  // Far range: lasso the ridge, fill a hazy gradient, blur it into the distance.
  await addLayerViaUi(tester, _farRangeLayerName);
  await selectLassoViaUi(tester, _farRidgeOutline());
  await gradientFillViaUi(
    tester,
    mode: FillMode.linear,
    tapPoint: _farRangeTap,
    start: _farRangeGradientStart,
    end: _farRangeGradientEnd,
    colors: _farRangeColors,
    stops: _twoStops,
  );
  await clearSelectionViaUi(tester);
  await applyEffectViaUi(tester, SelectionEffect.blur, strength: _farRangeBlurStrength, requireApply: true);
  await clearSelectionViaUi(tester);

  // Main peaks body.
  await addLayerViaUi(tester, _peaksLayerName);
  for (final (List<Offset> outline, Offset tap) in <(List<Offset>, Offset)>[
    (_peakWestOutline, _peakWestTap),
    (_peakEastOutline, _peakEastTap),
  ]) {
    await selectLassoViaUi(tester, outline);
    await gradientFillViaUi(
      tester,
      mode: FillMode.linear,
      tapPoint: tap,
      start: _peakBodyGradientStart,
      end: _peakBodyGradientEnd,
      colors: _peakBodyColors,
      stops: _twoStops,
    );
  }
  await clearSelectionViaUi(tester);

  // Alpenglow and snow on a scratch layer, merged down when done.
  await addLayerViaUi(tester, _alpenglowLayerName);
  for (final (List<Offset> face, Offset tap, Offset start, Offset end) in <(List<Offset>, Offset, Offset, Offset)>[
    (_peakWestLitFace, _peakWestLitTap, _peakWestOutline[13], _peakWestLitEnd),
    (_peakEastLitFace, _peakEastLitTap, _peakEastOutline[10], _peakEastLitEnd),
  ]) {
    await selectLassoViaUi(tester, face);
    await gradientFillViaUi(
      tester,
      mode: FillMode.linear,
      tapPoint: tap,
      start: start,
      end: end,
      colors: _alpenglowColors,
      stops: _alpenglowStops,
    );
  }
  for (final (List<Offset> cap, Offset tap, bool litFromEast) in <(List<Offset>, Offset, bool)>[
    (_snowWest, _snowWestTap, true),
    (_snowEast, _snowEastTap, false),
  ]) {
    final Rect bounds = _boundsOf(cap);
    await selectLassoViaUi(tester, cap);
    await gradientFillViaUi(
      tester,
      mode: FillMode.linear,
      tapPoint: tap,
      start: bounds.centerLeft,
      end: bounds.centerRight,
      colors: litFromEast ? <Color>[_snowShadeColor, _snowLitColor] : <Color>[_snowLitColor, _snowShadeColor],
      stops: _twoStops,
    );
  }
  await clearSelectionViaUi(tester);
  await mergeSelectedLayerDownViaUi(tester, mergedName: _peaksLayerName);

  // Rock texture with the grain brush, couloirs and ridge light with the pencil.
  await selectBrushTool(tester);
  await selectBrushStyleViaUi(tester, BrushStyle.grain);
  appProviderFromTester(tester).brushColor = _rockTextureColor;
  await setBrushSizeViaSlider(tester, _rockTextureSize);
  for (final List<Offset> stroke in _rockTextureStrokes) {
    await paintCanvasStroke(tester, stroke);
  }
  await selectPencilTool(tester);
  appProviderFromTester(tester).brushColor = _couloirColor;
  await setBrushSizeViaSlider(tester, _couloirSize);
  for (final List<Offset> stroke in _couloirStrokes) {
    await paintCanvasStroke(tester, stroke);
  }
  appProviderFromTester(tester).brushColor = _ridgeLightColor;
  await setBrushSizeViaSlider(tester, _ridgeLightSize);
  await paintCanvasStroke(tester, _peakWestLitRidge);
  await paintCanvasStroke(tester, _peakEastLitRidge);

  // Drag the snow down into the rock.
  await selectToolByKey(tester, Keys.toolSmudge);
  await setBrushSizeViaSlider(tester, _snowlineSmudgeSize);
  await setBrushIntensityViaSlider(tester, _snowlineSmudgeIntensity);
  for (final List<Offset> stroke in _snowlineSmudges) {
    await paintCanvasStroke(tester, stroke);
  }

  // Effects are brushes: light the ridges, enrich the glow, crisp the snow.
  await armEffectBrushViaUi(
    tester,
    SelectionEffect.brightness,
    strength: _ridgeBrightnessStrength,
    brushSize: _ridgeBrightnessSize,
  );
  await paintCanvasStroke(tester, _peakWestLitRidge);
  await paintCanvasStroke(tester, _peakEastLitRidge);
  await armEffectBrushViaUi(
    tester,
    SelectionEffect.saturation,
    strength: _glowSaturationStrength,
    brushSize: _glowSaturationSize,
  );
  for (final List<Offset> stroke in _glowSaturationStrokes) {
    await paintCanvasStroke(tester, stroke);
  }
  await armEffectBrushViaUi(
    tester,
    SelectionEffect.sharpness,
    strength: _snowSharpnessStrength,
    brushSize: _snowSharpnessSize,
  );
  for (final List<Offset> stroke in _snowSharpnessStrokes) {
    await paintCanvasStroke(tester, stroke);
  }
  await disarmEffectBrushViaUi(tester);

  await mergeSelectedLayerDownViaUi(tester, mergedName: _mountainsLayerName);
}

/// Bounding box of [points].
Rect _boundsOf(List<Offset> points) {
  Rect bounds = Rect.fromPoints(points.first, points.first);
  for (final Offset point in points.skip(1)) {
    bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
  }
  return bounds;
}
