part of '../painting_scenario_test.dart';

// Shore: dark foreground banks that frame the lake, rim-lit by the sunset,
// with hatch-mark grass, rocks, reeds and a noise-brush texture.

const String _shoreLayerName = 'Shore';

const List<Offset> _shoreWestOutline = <Offset>[
  Offset(-12, 612), Offset(40, 604), Offset(90, 600), Offset(140, 606), Offset(190, 620), //
  Offset(240, 640), Offset(282, 662), Offset(318, 688), Offset(346, 716), Offset(368, 746),
  Offset(380, 780), Offset(-12, 780),
];
const List<Offset> _shoreEastOutline = <Offset>[
  Offset(700, 780), Offset(718, 756), Offset(744, 734), Offset(780, 714), Offset(824, 700), //
  Offset(870, 690), Offset(920, 684), Offset(972, 680), Offset(1036, 674), Offset(1036, 780),
];

/// The water-facing top edge of each bank (for rim light and grass).
List<Offset> _shoreWestEdge() => _shoreWestOutline.sublist(0, _shoreWestOutline.length - 1);
List<Offset> _shoreEastEdge() => _shoreEastOutline.sublist(1, _shoreEastOutline.length - 1);

const List<Color> _shoreColors = <Color>[Color(0xFF3A3524), Color(0xFF12110C)];
const Offset _shoreGradientStart = Offset(0, 600);
const Offset _shoreGradientEnd = Offset(0, _sceneHeight);
const Offset _shoreWestTap = Offset(100, 700);
const Offset _shoreEastTap = Offset(900, 740);

const Color _shoreRimColor = Color(0x88E89A66);
const double _shoreRimSize = 5;

/// Grass: hatch marks fanning up from the bank edge.
const HatchMarks _grassMarks = HatchMarks(angleDegrees: 98, spacing: 3, length: 24, taperPercent: 90, curvePercent: 25);
const HatchMarks _grassTipMarks = HatchMarks(
  angleDegrees: 104,
  spacing: 5,
  length: 12,
  taperPercent: 95,
  curvePercent: 35,
);
const Color _grassColor = Color(0xFF1C2213);
const Color _grassTipColor = Color(0xCCB58A4A);
const double _grassSize = 2.6;
const double _grassTipSize = 1.6;
const double _grassEdgeDrop = 6;

/// Rocks at the water's edge, rim-lit on the sun side.
const List<(Offset, double)> _rocks = <(Offset, double)>[
  (Offset(326, 702), 15),
  (Offset(356, 738), 11),
  (Offset(296, 678), 9),
  (Offset(742, 746), 12),
];
const Color _rockColor = Color(0xFF15120E);
const Color _rockRimColor = Color(0xE6E8A070);
const double _rockRimSize = 1.8;
const double _rockRimStartAngle = -math.pi * 0.7;
const double _rockRimSweep = math.pi * 0.55;
const int _rockRimSamples = 6;

/// Reeds along the west bank's waterline.
const int _reedCount = 16;
const double _reedMinHeight = 26;
const double _reedHeightRange = 40;
const double _reedLean = 9;
const Color _reedColor = Color(0xFF14160E);
const double _reedSize = 1.4;
const double _reedHeadSize = 4;
const double _reedHeadLength = 6;

/// Film-grain texture over the whole bank layer.
const double _shoreNoiseStrength = 0.15;

Future<void> paintShowcaseShore(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  await addLayerViaUi(tester, _shoreLayerName);

  for (final (List<Offset> outline, Offset tap) in <(List<Offset>, Offset)>[
    (_shoreWestOutline, _shoreWestTap),
    (_shoreEastOutline, _shoreEastTap),
  ]) {
    await selectLassoViaUi(tester, outline);
    await gradientFillViaUi(
      tester,
      mode: FillMode.linear,
      tapPoint: tap,
      start: Offset(tap.dx, _shoreGradientStart.dy),
      end: Offset(tap.dx, _shoreGradientEnd.dy),
      colors: _shoreColors,
      stops: _twoStops,
    );
  }
  await clearSelectionViaUi(tester);

  // Rim light along the water-facing edges.
  await selectBrushTool(tester);
  await selectBrushStyleViaUi(tester, BrushStyle.soft);
  appProviderFromTester(tester).brushColor = _shoreRimColor;
  await setBrushSizeViaSlider(tester, _shoreRimSize);
  await paintCanvasStroke(tester, _shoreWestEdge());
  await paintCanvasStroke(tester, _shoreEastEdge());

  // Grass: two passes of hatch marks — dark blades, then sunlit tips.
  await selectBrushStyleViaUi(tester, BrushStyle.hatchMarks);
  for (final (HatchMarks marks, Color color, double size) in <(HatchMarks, Color, double)>[
    (_grassMarks, _grassColor, _grassSize),
    (_grassTipMarks, _grassTipColor, _grassTipSize),
  ]) {
    applyHatchMarks(tester, marks);
    appProviderFromTester(tester).brushColor = color;
    await setBrushSizeViaSlider(tester, size);
    for (final List<Offset> edge in <List<Offset>>[_shoreWestEdge(), _shoreEastEdge()]) {
      await paintCanvasStroke(tester, <Offset>[
        for (final Offset point in edge) point + const Offset(0, _grassEdgeDrop),
      ]);
    }
  }

  // Rocks: borderless circles, then a pencil rim on the sun side.
  await selectToolByKey(tester, Keys.toolCircle);
  await selectBrushStyleViaUi(tester, BrushStyle.solid);
  appProviderFromTester(tester)
    ..fillColor = _rockColor
    ..brushColor = _rockColor;
  await setBrushSizeViaSlider(tester, 0);
  for (final (Offset center, double radius) in _rocks) {
    await dragCanvasShape(tester, from: center - Offset(radius, 0), to: center + Offset(radius, 0));
  }
  await selectPencilTool(tester);
  appProviderFromTester(tester).brushColor = _rockRimColor;
  await setBrushSizeViaSlider(tester, _rockRimSize);
  for (final (Offset center, double radius) in _rocks) {
    await paintCanvasStroke(tester, <Offset>[
      for (int sample = 0; sample <= _rockRimSamples; sample++)
        center +
            Offset.fromDirection(_rockRimStartAngle + _rockRimSweep * sample / _rockRimSamples, radius * _rockRimInset),
    ]);
  }

  // Reeds along the west bank's water edge.
  appProviderFromTester(tester).brushColor = _reedColor;
  final math.Random random = math.Random(_grassSeed);
  final List<Offset> waterEdge = _shoreWestEdge().sublist(_reedEdgeFirstVertex);
  for (int reed = 0; reed < _reedCount; reed++) {
    final double t = reed / (_reedCount - AppMath.one);
    final int segment = math.min((t * (waterEdge.length - AppMath.pair)).floor(), waterEdge.length - AppMath.pair);
    final Offset base = Offset.lerp(waterEdge[segment], waterEdge[segment + 1], random.nextDouble())!;
    final double height = _reedMinHeight + random.nextDouble() * _reedHeightRange;
    final Offset tip = base + Offset((random.nextDouble() - AppVisual.half) * _reedLean * AppMath.pair, -height);
    await setBrushSizeViaSlider(tester, _reedSize);
    await paintCanvasStroke(
      tester,
      <Offset>[base, Offset.lerp(base, tip, AppVisual.half)! + const Offset(_reedLean / AppMath.pair, 0), tip],
      captureFrame: false,
    );
    if (reed.isEven) {
      await setBrushSizeViaSlider(tester, _reedHeadSize);
      await paintCanvasStroke(
        tester,
        <Offset>[tip + const Offset(0, _reedHeadLength), tip + const Offset(0, _reedHeadLength * AppMath.pair)],
        captureFrame: false,
      );
    }
  }
  await captureShowcaseFrame(tester);

  // Texture: a fine noise over the whole bank layer, from the effects menu.
  await applyEffectViaUi(tester, SelectionEffect.noise, strength: _shoreNoiseStrength, requireApply: true);
  await clearSelectionViaUi(tester);
}

/// Rocks' rim highlight sits just inside the silhouette.
const double _rockRimInset = 0.88;

/// Reeds grow from the steep, water-facing part of the west bank.
const int _reedEdgeFirstVertex = 5;
