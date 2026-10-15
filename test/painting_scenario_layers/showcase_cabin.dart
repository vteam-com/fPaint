part of '../painting_scenario_test.dart';

// Cabin: a small timber cabin on the east bank with a glowing window and a
// curl of chimney smoke — painted zoomed in with a trackpad pinch, the way an
// artist works on detail.

const String _cabinLayerName = 'Cabin';

const Offset _cabinFocus = Offset(842, 660);
const double _cabinZoom = 2.4;
const Offset _cabinPan = Offset(-60, -20);

const Rect _cabinBody = Rect.fromLTRB(800, 652, 882, 702);
const Color _cabinWallColor = Color(0xFF3B2A24);
const Color _cabinTrimColor = Color(0xFF1A120F);
const double _cabinTrimSize = 2;

/// Siding: a horizontal hatch fill over the wall.
const HatchPattern _sidingPattern = HatchPattern(angleDegrees: 0, spacing: 5, lineWidth: 1);
const Color _sidingColor = Color(0xCC1E140E);
const Offset _sidingTap = Offset(842, 694);

/// Roof: a straight-edge marquee filled solid, rim-lit on the sun side.
const List<Offset> _cabinRoof = <Offset>[Offset(788, 655), Offset(841, 613), Offset(894, 655)];
const Color _cabinRoofColor = Color(0xFF231917);
const Offset _cabinRoofTap = Offset(841, 640);

/// Shingle texture: halftone dots, a shade lighter than the roof.
const Color _shingleColor = Color(0xFF4A3428);
const int _shingleDotSizePercent = 45;
const Color _cabinRimColor = Color(0xF2F0A070);
const double _cabinRimSize = 2;

const Rect _cabinChimney = Rect.fromLTRB(860, 610, 871, 636);

/// The lit window: a wand pick of the pane, filled with a radial glow.
const Rect _cabinWindow = Rect.fromLTRB(810, 665, 832, 685);
const Color _cabinWindowBaseColor = Color(0xFFFFB14A);
const List<Color> _cabinWindowGlow = <Color>[Color(0xFFFFF3C4), Color(0xFFFF9A3A)];
const int _cabinWindowWandTolerance = 30;

/// Screen pixels the wand is scrubbed right to widen its tolerance a little.
const double _cabinWindowWandScrub = 24;
const Color _cabinLightSpillColor = Color(0x55FFB347);
const double _cabinLightSpillSize = 30;

/// Door: first painted in a colour that is too bright, undone, then repainted.
const Rect _cabinDoor = Rect.fromLTRB(852, 670, 868, 702);
const Color _cabinDoorWrongColor = Color(0xFFB0764E);
const Color _cabinDoorColor = Color(0xFF2A1C18);

/// Chimney smoke, softened with the smudge tool.
const Color _smokeColor = Color(0x70C9B6D6);
const double _smokeSize = 9;
const List<Offset> _smokePath = <Offset>[
  Offset(865, 608), Offset(860, 590), Offset(870, 572), Offset(886, 558), Offset(894, 540), Offset(912, 524), //
  Offset(936, 514),
];

/// The cabin sits on the sloping east bank: a mound of earth under its base
/// fills the gap the slope leaves, and grass painted in front overlaps the foot
/// of the walls so the building reads as standing in the ground, not on it.
const List<Offset> _cabinMound = <Offset>[
  Offset(770, 720), Offset(788, 708), Offset(810, 702), Offset(850, 700), Offset(892, 700), Offset(914, 704), //
  Offset(932, 714), Offset(932, 734), Offset(770, 734),
];
const Color _cabinMoundColor = Color(0xFF2B271B);
const Offset _cabinMoundTap = Offset(850, 720);
const List<Offset> _cabinGrassLine = <Offset>[
  Offset(774, 716), Offset(792, 708), Offset(812, 705), Offset(840, 704), Offset(868, 704), Offset(896, 703), //
  Offset(916, 707), Offset(930, 714),
];

const double _smokeSmudgeSize = 14;
const double _smokeSmudgeIntensity = 0.6;
const Offset _smokeDrift = Offset(10, -6);

Future<void> paintShowcaseCabin(PaintingScenarioSession session) async {
  final WidgetTester tester = session.tester;
  await addLayerViaUi(tester, _cabinLayerName);
  await trackpadZoomViaUi(tester, canvasFocus: _cabinFocus, scale: _cabinZoom);
  await trackpadPanViaUi(tester, canvasFocus: _cabinFocus, screenDelta: _cabinPan);

  // Ground first: a lassoed mound of earth for the cabin to stand on.
  await selectLassoViaUi(tester, _cabinMound);
  await solidFillViaUi(tester, canvasPoint: _cabinMoundTap, color: _cabinMoundColor);
  await clearSelectionViaUi(tester);

  // Walls and chimney: filled rectangles with a dark trim.
  await selectToolByKey(tester, Keys.toolRectangle);
  await selectBrushStyleViaUi(tester, BrushStyle.solid);
  final AppProvider appProvider = appProviderFromTester(tester);
  appProvider
    ..fillColor = _cabinWallColor
    ..brushColor = _cabinTrimColor;
  await setBrushSizeViaSlider(tester, _cabinTrimSize);
  await dragCanvasShape(tester, from: _cabinBody.topLeft, to: _cabinBody.bottomRight);

  // Siding: the paint bucket's hatching mode over the wall.
  await tapByKey(tester, Keys.toolFill);
  await tapByKey(tester, Keys.toolFillModeSolid);
  appProvider.hatchPattern = _sidingPattern;
  await tapByKey(tester, Keys.toolFillHatchToggle);
  expect(appProvider.fillModel.hatchEnabled, isTrue, reason: 'Hatching should be enabled for the siding');
  await solidFillViaUi(tester, canvasPoint: _sidingTap, color: _sidingColor);
  await tapByKey(tester, Keys.toolFillHatchToggle);

  // Roof: click the three corners of a straight-edge marquee, then fill it.
  await selectPolygonViaUi(tester, _cabinRoof);
  await solidFillViaUi(tester, canvasPoint: _cabinRoofTap, color: _cabinRoofColor);

  // Shingles: a second, halftone pass of dots over the roof.
  await setFillHalftoneViaUi(tester, enabled: true, dotSizePercent: _shingleDotSizePercent);
  await solidFillViaUi(tester, canvasPoint: _cabinRoofTap, color: _shingleColor);
  await setFillHalftoneViaUi(tester, enabled: false);
  await clearSelectionViaUi(tester);

  await selectToolByKey(tester, Keys.toolRectangle);
  appProvider
    ..fillColor = _cabinRoofColor
    ..brushColor = _cabinRoofColor;
  await setBrushSizeViaSlider(tester, 0);
  await dragCanvasShape(tester, from: _cabinChimney.topLeft, to: _cabinChimney.bottomRight);

  await selectPencilTool(tester);
  appProvider.brushColor = _cabinRimColor;
  await setBrushSizeViaSlider(tester, _cabinRimSize);
  await paintCanvasStroke(tester, <Offset>[_cabinRoof[0], _cabinRoof[1]]);
  await paintCanvasStroke(tester, <Offset>[_cabinChimney.topLeft, _cabinChimney.bottomLeft]);

  // Window: a bright pane, then a wand pick of it filled with a radial glow.
  await selectToolByKey(tester, Keys.toolRectangle);
  appProvider
    ..fillColor = _cabinWindowBaseColor
    ..brushColor = _cabinTrimColor;
  await setBrushSizeViaSlider(tester, _cabinTrimSize);
  await dragCanvasShape(tester, from: _cabinWindow.topLeft, to: _cabinWindow.bottomRight);
  appProvider.tolerance = _cabinWindowWandTolerance;
  await selectWandWithToleranceDragViaUi(
    tester,
    canvasPoint: _cabinWindow.center,
    toleranceDragDx: _cabinWindowWandScrub,
  );
  await gradientFillViaUi(
    tester,
    mode: FillMode.radial,
    tapPoint: _cabinWindow.center,
    start: _cabinWindow.center,
    end: _cabinWindow.centerRight,
    colors: _cabinWindowGlow,
    stops: _twoStops,
  );
  await clearSelectionViaUi(tester);

  // Door: the first colour reads too bright — undo it and repaint.
  await selectToolByKey(tester, Keys.toolRectangle);
  appProvider
    ..fillColor = _cabinDoorWrongColor
    ..brushColor = _cabinTrimColor;
  await dragCanvasShape(tester, from: _cabinDoor.topLeft, to: _cabinDoor.bottomRight);
  final int actionsWithWrongDoor = appProvider.layers.selectedLayer.actionStack.length;
  await tapByKey(tester, Keys.floatActionUndo);
  expect(appProvider.layers.selectedLayer.actionStack.length, actionsWithWrongDoor - AppMath.one);
  await tapByKey(tester, Keys.floatActionRedo);
  expect(appProvider.layers.selectedLayer.actionStack.length, actionsWithWrongDoor);
  await tapByKey(tester, Keys.floatActionUndo);
  appProvider.fillColor = _cabinDoorColor;
  await dragCanvasShape(tester, from: _cabinDoor.topLeft, to: _cabinDoor.bottomRight);

  // Warm light spilling onto the wall.
  await selectBrushTool(tester);
  await selectBrushStyleViaUi(tester, BrushStyle.soft);
  appProvider.brushColor = _cabinLightSpillColor;
  await setBrushSizeViaSlider(tester, _cabinLightSpillSize);
  await paintCanvasStroke(tester, <Offset>[_cabinWindow.centerLeft, _cabinWindow.center, _cabinWindow.centerRight]);

  // Grass in front of the base, reusing the bank's hatch-mark blades.
  await selectBrushStyleViaUi(tester, BrushStyle.hatchMarks);
  for (final (HatchMarks marks, Color color, double size) in <(HatchMarks, Color, double)>[
    (_grassMarks, _grassColor, _grassSize),
    (_grassTipMarks, _grassTipColor, _grassTipSize),
  ]) {
    applyHatchMarks(tester, marks);
    appProvider.brushColor = color;
    await setBrushSizeViaSlider(tester, size);
    await paintCanvasStroke(tester, _cabinGrassLine);
  }
  await selectBrushStyleViaUi(tester, BrushStyle.soft);

  // Smoke: a soft wisp, smudged downwind.
  appProvider.brushColor = _smokeColor;
  await setBrushSizeViaSlider(tester, _smokeSize);
  await paintCanvasStroke(tester, _smokePath);
  await selectToolByKey(tester, Keys.toolSmudge);
  await setBrushSizeViaSlider(tester, _smokeSmudgeSize);
  await setBrushIntensityViaSlider(tester, _smokeSmudgeIntensity);
  for (int index = AppMath.pair; index < _smokePath.length; index += AppMath.pair) {
    await paintCanvasStroke(tester, <Offset>[
      _smokePath[index - 1],
      _smokePath[index],
      _smokePath[index] + _smokeDrift,
    ]);
  }

  await showActualSizeCentered(tester);

  // Which layer is that? Pick the peak with the panel's picker puck, then
  // Shift+Alt-click the cabin to come back to it.
  expect(await pickLayerWithPuckViaUi(tester, _pickerMountainPoint), _mountainsLayerName);
  expect(await pickLayerWithShortcutViaUi(tester, _cabinBody.center), _cabinLayerName);
}

/// A pixel only the mountains own (the west peak's shadow face, above the trees).
const Offset _pickerMountainPoint = Offset(200, 330);
