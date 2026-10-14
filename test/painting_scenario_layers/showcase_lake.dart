part of '../painting_scenario_test.dart';

// Lake: the water mirrors the sky (gradient inside a rectangle marquee), and a
// reflection layer mirrors the mountains and trees — painted upright, then
// flipped about the waterline with the toolbar's Flip Vertical, blurred, faded,
// and broken into ripples with the eraser.

const String _lakeLayerName = 'Lake';
const String _reflectionLayerName = 'Reflection';

const List<Color> _lakeColors = <Color>[
  Color(0xFFFFC77F), // gold at the waterline
  Color(0xFFE8875F),
  Color(0xFFA8466E),
  Color(0xFF50306E),
  Color(0xFF1C1A3A), // deep water in the foreground
];
const List<double> _lakeStops = <double>[0, 0.14, 0.42, 0.72, 1];
const Offset _lakeTap = Offset(_sceneWidth / AppMath.pair, 620);
const Offset _lakeGradientStart = Offset(_sceneWidth / AppMath.pair, _waterlineY);
const Offset _lakeGradientEnd = Offset(_sceneWidth / AppMath.pair, _sceneHeight);

/// Reflection colours: darker, cooler versions of what they mirror.
const Color _reflectionFarColor = Color(0xFF6E5A8E);
const Color _reflectionPeakColor = Color(0xFF2E2A52);
const Color _reflectionGlowColor = Color(0xFF7A4A6E);
const Color _reflectionTreeColor = Color(0xC00E1426);
const double _reflectionTreeLengthRatio = 0.85;
const double _reflectionTreeSizeRatio = 0.55;
const double _reflectionBlurStrength = 0.55;
const double _reflectionOpacity = 0.62;

/// Eraser ripples that break the mirror into horizontal slivers.
const int _rippleCount = 48;
const double _rippleTop = _waterlineY + 8;
const double _rippleMinLength = 18;
const double _rippleLengthRange = 70;
const double _rippleSize = 1.3;

Future<void> paintShowcaseLake(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  await addLayerViaUi(tester, _lakeLayerName);
  await selectRectangleViaUi(
    tester,
    from: const Offset(-_edgeBleed, _waterlineY),
    to: const Offset(_sceneWidth + _edgeBleed, _sceneHeight + _edgeBleed),
  );
  await gradientFillViaUi(
    tester,
    mode: FillMode.linear,
    tapPoint: _lakeTap,
    start: _lakeGradientStart,
    end: _lakeGradientEnd,
    colors: _lakeColors,
    stops: _lakeStops,
  );
  await clearSelectionViaUi(tester);
}

Future<void> paintShowcaseReflection(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  final AppLocalizations l10n = mainViewContext(tester).l10n;
  await addLayerViaUi(tester, _reflectionLayerName);

  // Paint the mirror image upright first, exactly over the real shapes.
  for (final (List<Offset> outline, Offset tap, Color color) in <(List<Offset>, Offset, Color)>[
    (_farRidgeOutline(), _farRangeTap, _reflectionFarColor),
    (_peakWestOutline, _peakWestTap, _reflectionPeakColor),
    (_peakEastOutline, _peakEastTap, _reflectionPeakColor),
    (_peakWestLitFace, _peakWestLitTap, _reflectionGlowColor),
    (_peakEastLitFace, _peakEastLitTap, _reflectionGlowColor),
  ]) {
    await selectLassoViaUi(tester, outline);
    await solidFillViaUi(tester, canvasPoint: tap, color: color);
  }
  await clearSelectionViaUi(tester);

  // Soft vertical smears for the trees' reflections.
  await selectBrushTool(tester);
  await selectBrushStyleViaUi(tester, BrushStyle.soft);
  appProviderFromTester(tester).brushColor = _reflectionTreeColor;
  for (final ({Offset base, double height, double width}) pine in _pineForest()) {
    await setBrushSizeViaSlider(tester, pine.width * _reflectionTreeSizeRatio);
    await paintCanvasStroke(
      tester,
      <Offset>[
        Offset(pine.base.dx, _waterlineY),
        Offset(pine.base.dx, _waterlineY - pine.height * _reflectionTreeLengthRatio),
      ],
      captureFrame: false,
    );
  }
  await captureShowcaseFrame(tester);

  // Mirror it all into the lake: a marquee centred on the waterline, flipped.
  await selectRectangleViaUi(tester, from: _reflectionFlipRect.topLeft, to: _reflectionFlipRect.bottomRight);
  await tapByTooltip(tester, l10n.flipVerticalTooltip);
  await pumpUntilIdle(tester, () => true);
  await clearSelectionViaUi(tester);

  await applyEffectViaUi(tester, SelectionEffect.blur, strength: _reflectionBlurStrength, requireApply: true);
  await clearSelectionViaUi(tester);
  await setLayerOpacityViaUi(tester, layerName: _reflectionLayerName, opacity: _reflectionOpacity);

  // Ripples: the eraser cuts thin horizontal slivers out of the mirror.
  await selectEraserTool(tester);
  await setBrushSizeViaSlider(tester, _rippleSize);
  final math.Random random = math.Random(_rippleSeed);
  for (int ripple = 0; ripple < _rippleCount; ripple++) {
    final double t = ripple / _rippleCount;
    final double y = _rippleTop + (_sceneHeight - _rippleTop) * t * t;
    final double length = _rippleMinLength + random.nextDouble() * _rippleLengthRange * (AppMath.one + t);
    final double x = random.nextDouble() * (_sceneWidth - length);
    await paintCanvasStroke(
      tester,
      <Offset>[Offset(x, y), Offset(x + length / AppMath.pair, y), Offset(x + length, y)],
      captureFrame: ripple.isEven,
    );
  }
}
