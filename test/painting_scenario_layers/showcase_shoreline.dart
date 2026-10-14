part of '../painting_scenario_test.dart';

// Shoreline: the far shore strip and its pine forest, plus the sun's glittering
// path on the water — dashed Line-tool strokes punched up with effect brushes.

const String _shorelineLayerName = 'Shoreline';

const Color _forestColor = Color(0xFF0C1120);
const double _pineStrokeSize = 3.2;
const double _shoreStripTop = _waterlineY - 4;
const double _shoreStripBottom = _waterlineY + 7;

/// Sun path: dashes widen and thin out toward the viewer.
const int _glitterRows = 26;
const double _glitterTop = _waterlineY + 6;
const double _glitterBottom = 690;
const double _glitterMinHalfWidth = 10;
const double _glitterSpread = 0.42;
const double _glitterJitter = 9;
const double _glitterSize = 2.4;
const List<Color> _glitterColors = <Color>[Color(0xF2FFE7AE), Color(0xD9FFC27A), Color(0xE6FFF3D2)];

/// Effect brushes that make the path shimmer.
const double _glitterBrightnessStrength = 0.4;
const double _glitterBrightnessSize = 70;
const double _glitterSaturationStrength = 0.3;
const double _glitterSaturationSize = 110;

Future<void> paintShowcaseShoreline(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  await addLayerViaUi(tester, _shorelineLayerName);

  // Far shore: a thin borderless rectangle the trees stand on.
  await selectToolByKey(tester, Keys.toolRectangle);
  await selectBrushStyleViaUi(tester, BrushStyle.solid);
  final AppProvider appProvider = appProviderFromTester(tester);
  appProvider.fillColor = _forestColor;
  appProvider.brushColor = _forestColor;
  await setBrushSizeViaSlider(tester, 0);
  await dragCanvasShape(
    tester,
    from: const Offset(-_edgeBleed, _shoreStripTop),
    to: const Offset(_sceneWidth + _edgeBleed, _shoreStripBottom),
  );

  // The forest: one zig-zag pencil stroke per pine.
  await selectPencilTool(tester);
  await setBrushSizeViaSlider(tester, _pineStrokeSize);
  final List<({Offset base, double height, double width})> pines = _pineForest();
  for (int index = 0; index < pines.length; index++) {
    final ({Offset base, double height, double width}) pine = pines[index];
    await paintCanvasStroke(
      tester,
      _pinePoints(base: pine.base, height: pine.height, width: pine.width),
      captureFrame: index.isEven,
    );
  }

  // Sun path: dashed Line-tool strokes under the sun.
  await selectToolByKey(tester, Keys.toolLine);
  await selectBrushStyleViaUi(tester, BrushStyle.dash);
  await setBrushSizeViaSlider(tester, _glitterSize);
  final math.Random random = math.Random(_glitterSeed);
  for (int row = 0; row < _glitterRows; row++) {
    final double t = row / (_glitterRows - AppMath.one);
    final double y = _glitterTop + (_glitterBottom - _glitterTop) * t;
    final double halfWidth = _glitterMinHalfWidth + (y - _waterlineY) * _glitterSpread;
    final double centerX = _sunCenter.dx + (random.nextDouble() - AppVisual.half) * _glitterJitter;
    appProvider.brushColor = _glitterColors[row % _glitterColors.length];
    await dragCanvasShape(
      tester,
      from: Offset(centerX - halfWidth * random.nextDouble(), y),
      to: Offset(centerX + halfWidth * random.nextDouble(), y),
      captureFrame: row.isEven,
    );
  }

  // Effects as brushes: brighten and warm the path where the sun hits.
  final Offset sunReflection = _mirrorAcrossWaterline(_sunCenter);
  await armEffectBrushViaUi(
    tester,
    SelectionEffect.brightness,
    strength: _glitterBrightnessStrength,
    brushSize: _glitterBrightnessSize,
  );
  await paintCanvasStroke(tester, <Offset>[
    Offset(_sunCenter.dx, _glitterTop),
    sunReflection,
    Offset(_sunCenter.dx, _glitterBottom),
  ]);
  await armEffectBrushViaUi(
    tester,
    SelectionEffect.saturation,
    strength: _glitterSaturationStrength,
    brushSize: _glitterSaturationSize,
  );
  await paintCanvasStroke(tester, <Offset>[
    Offset(_sunCenter.dx, _glitterTop),
    Offset(_sunCenter.dx, _glitterBottom),
  ]);
  await disarmEffectBrushViaUi(tester);
}
