part of '../painting_scenario_test.dart';

// Sky: a five-stop sunset gradient laid down with a real paint-bucket gradient
// session, a scatter of early stars, and a soft sun with a screen-blended glow.

const String _skyLayerName = 'Sky';
const String _sunLayerName = 'Sun';

/// Zenith-to-horizon sunset stops.
const List<Color> _skyColors = <Color>[
  Color(0xFF141432), // night indigo
  Color(0xFF3B2A66), // violet
  Color(0xFF9B3D6E), // magenta rose
  Color(0xFFE8743B), // ember orange
  Color(0xFFFFC873), // horizon gold
];
const List<double> _skyStops = <double>[0, 0.30, 0.56, 0.80, 1];
const Offset _skyGradientTap = Offset(_sceneWidth / AppMath.pair, _waterlineY / AppMath.pair);
const Offset _skyGradientStart = Offset(_sceneWidth / AppMath.pair, 0);
const Offset _skyGradientEnd = Offset(_sceneWidth / AppMath.pair, _waterlineY);

/// Stars only appear in the darkest band of the sky.
const int _starCount = 34;
const double _starFieldBottom = 170;
const double _starMinSize = 1.2;
const double _starSizeRange = 1.8;
const Color _starColor = Color(0xE6FFF6E8);
const double _starDabLength = 0.6;

/// Sun body and the radial glow around it.
const double _sunRadius = 30;
const double _sunGlowRadius = 330;
const List<Color> _sunGlowColors = <Color>[
  Color(0xE6FFE9A8),
  Color(0x80FF9A4A),
  Color(0x00FF7A3A),
];
const List<double> _sunGlowStops = <double>[0, 0.3, 1];
const Color _sunBodyColor = Color(0xFFFFF4D6);
const double _sunBlurStrength = 0.35;

Future<void> paintShowcaseSky(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  await addLayerViaUi(tester, _skyLayerName);
  await gradientFillViaUi(
    tester,
    mode: FillMode.linear,
    tapPoint: _skyGradientTap,
    start: _skyGradientStart,
    end: _skyGradientEnd,
    colors: _skyColors,
    stops: _skyStops,
  );

  // Stars: tiny pencil dabs, sized and placed by a fixed-seed generator.
  await selectPencilTool(tester);
  await pickBrushColorViaUi(tester, _starColor);
  final math.Random random = math.Random(_starSeed);
  for (int star = 0; star < _starCount; star++) {
    final Offset position = Offset(
      random.nextDouble() * _sceneWidth,
      random.nextDouble() * random.nextDouble() * _starFieldBottom,
    );
    await setBrushSizeViaSlider(tester, _starMinSize + random.nextDouble() * _starSizeRange);
    await paintCanvasStroke(
      tester,
      <Offset>[position, position + const Offset(_starDabLength, 0)],
      captureFrame: star.isEven,
    );
  }
}

Future<void> paintShowcaseSun(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  final AppLocalizations l10n = mainViewContext(tester).l10n;
  await addLayerViaUi(tester, _sunLayerName);

  // The glow: a radial gradient on the empty layer, from warm white to clear.
  await gradientFillViaUi(
    tester,
    mode: FillMode.radial,
    tapPoint: _sunCenter,
    start: _sunCenter,
    end: _sunCenter + const Offset(_sunGlowRadius, 0),
    colors: _sunGlowColors,
    stops: _sunGlowStops,
  );

  // The disc: a borderless filled circle.
  await selectToolByKey(tester, Keys.toolCircle);
  await selectBrushStyleViaUi(tester, BrushStyle.solid);
  final AppProvider appProvider = appProviderFromTester(tester);
  appProvider.fillColor = _sunBodyColor;
  appProvider.brushColor = _sunBodyColor;
  await setBrushSizeViaSlider(tester, 0);
  await dragCanvasShape(
    tester,
    from: _sunCenter - const Offset(_sunRadius, 0),
    to: _sunCenter + const Offset(_sunRadius, 0),
  );

  // Soften the whole layer through the selection overlay's effects menu, then
  // let the glow add light to the sky instead of covering it.
  await applyEffectViaUi(tester, SelectionEffect.blur, strength: _sunBlurStrength, requireApply: true);
  await clearSelectionViaUi(tester);
  await setSelectedLayerBlendModeViaUi(
    tester,
    blendMode: BlendMode.screen,
    description: l10n.blendModeScreenDescription,
  );
}
