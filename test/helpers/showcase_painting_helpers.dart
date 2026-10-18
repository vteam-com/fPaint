// ignore_for_file: use_build_context_synchronously

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/hatch_marks.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/brush_intensity_picker.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/hatch_settings_picker.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:material_ui/material_ui.dart';

import 'painting_test_helpers.dart';

// ---------------------------------------------------------------------------
// Real-UI painting helpers for the showcase scenario.
//
// Unlike the older helpers in painting_test_helpers.dart, which seed several
// operations straight into the providers, these drive the app the way a person
// does: pick the tool in the panel, press on the canvas, drag, release. Async
// work the app starts from a gesture (isolate flood fills, pixel-brush commits,
// effect renders) needs the real event loop, so [pumpUntilIdle] alternates a
// short real-time slice with a frame pump until the app reports it is done.
// ---------------------------------------------------------------------------

/// Real-time slice handed to the event loop between fake-async pumps.
const Duration _realAsyncSlice = Duration(milliseconds: 4);

/// Upper bound on [pumpUntilIdle] iterations before giving up.
const int _maxIdlePumpIterations = 1500;

/// Fake-clock advance per [pumpUntilIdle] iteration, so debounced UI work
/// (double-tap disambiguation, thumbnail refresh) also gets to run.
const Duration _idleFramePump = Duration(milliseconds: 16);

/// Pause between pointer moves of a recorded stroke.
const Duration _strokeMovePump = Duration(milliseconds: 8);

/// Number of intermediate moves for handle and slider drags.
const int _handleDragSteps = 6;

/// Number of update events in a simulated trackpad pinch or pan.
const int _pinchUpdateSteps = 6;

/// Screen pixels per opacity-scrub nudge (1 px = 1 % on the thumbnail).
const double _opacityScrubStepPixels = 1;

/// Upper bound on opacity-scrub nudges.
const int _opacityScrubMaxSteps = 400;

/// Maximum follow-up nudges to land a dragged gradient handle on target.
const int _handleCorrectionMaxSteps = 8;

/// Distance, in screen pixels, at which a dragged handle counts as on target.
const double _handleTargetTolerance = 0.5;

/// How close to 1.0 a display-cache scale must be to count as full resolution.
const double _sharpCacheEpsilon = 0.001;

/// Attempts at placing both gradient knobs before giving up.
const int _gradientHandlePlacementAttempts = 3;

/// Canvas-pixel distance at which a gradient knob counts as placed.
const double _gradientHandleCanvasTolerance = 1.5;

/// Screen-pixel nudge applied while placing the layer picker puck.
const double _pickerNudge = 12;

/// Tolerance fill colours are compared with when verifying an eyedrop.
const int _eyedropChannelTolerance = 2;

/// Canvas-space position → global screen position of that canvas pixel.
Offset canvasToScreen(WidgetTester tester, Offset canvasPoint) {
  final AppProvider appProvider = appProviderFromTester(tester);
  final Offset handlerOrigin = tester.getTopLeft(find.byType(CanvasGestureHandler));
  return handlerOrigin + appProvider.fromCanvas(canvasPoint);
}

/// Pumps frames while letting real async work progress until [isIdle] holds.
///
/// Returns whether the condition was met before the iteration cap.
Future<bool> pumpUntilIdle(
  WidgetTester tester,
  bool Function() isIdle,
) async {
  for (int iteration = 0; iteration < _maxIdlePumpIterations; iteration++) {
    if (isIdle()) {
      return true;
    }
    await tester.runAsync(() => Future<void>.delayed(_realAsyncSlice));
    await tester.pump(_idleFramePump);
  }
  return isIdle();
}

/// Waits until the pixel-brush / effect-brush commit of the last stroke lands.
Future<void> waitForPixelBrushCommit(WidgetTester tester) async {
  final AppProvider appProvider = appProviderFromTester(tester);
  final bool idle = await pumpUntilIdle(
    tester,
    () => !appProvider.isPixelBrushCommitting && !appProvider.isPixelBrushGestureVisible,
  );
  expect(idle, isTrue, reason: 'Pixel-brush commit should finish');
}

/// Captures one video frame without settling animations.
Future<void> captureShowcaseFrame(WidgetTester tester) async {
  await UnitTestVideoRecorder.captureAfterInteraction(tester, settle: false);
}

// ---------------------------------------------------------------------------
// Tool selection
// ---------------------------------------------------------------------------

/// Tapping the panel button of a freehand tool that has no stable key.
Future<void> selectToolByLabel(WidgetTester tester, String label) async {
  await tapByTooltip(tester, label);
  await _settleToolPanel(tester);
}

/// Lets the tool panel's options cross-fade finish so only the new tool's
/// controls are on screen.
Future<void> _settleToolPanel(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppDefaults.toolPanelRevealAnimationDuration);
  await tester.pump();
}

/// Selects the Pencil tool from the Brush section.
Future<void> selectPencilTool(WidgetTester tester) => selectToolByLabel(tester, _l10n(tester).toolPencil);

/// Selects the Brush tool from the Brush section.
Future<void> selectBrushTool(WidgetTester tester) => selectToolByLabel(tester, _l10n(tester).toolBrush);

/// Selects the Eraser tool from the Brush section.
Future<void> selectEraserTool(WidgetTester tester) => selectToolByLabel(tester, _l10n(tester).toolEraser);

/// Selects the tool behind [key] (smudge, blur brush, line, rectangle, …).
Future<void> selectToolByKey(WidgetTester tester, Key key) async {
  await tapByKey(tester, key);
  await _settleToolPanel(tester);
}

AppLocalizations _l10n(WidgetTester tester) => mainViewContext(tester).l10n;

/// The localized label the brush-style dropdown shows for [style].
String brushStyleLabel(AppLocalizations l10n, BrushStyle style) {
  return switch (style) {
    BrushStyle.solid => l10n.brushStyleSolid,
    BrushStyle.dash => l10n.brushStyleDash,
    BrushStyle.dotted => l10n.brushStyleDotted,
    BrushStyle.dashDot => l10n.brushStyleDashDot,
    BrushStyle.slash => l10n.brushStyleSlash,
    BrushStyle.soft => l10n.brushStyleSoft,
    BrushStyle.grain => l10n.brushStyleGrain,
    BrushStyle.hatch => l10n.brushStyleHatch,
    BrushStyle.crossHatch => l10n.brushStyleCrossHatch,
    BrushStyle.hatchMarks => l10n.brushStyleHatchMarks,
  };
}

/// Picks [style] from the tool panel's brush-style dropdown.
///
/// The active tool must support brush styles (Brush, Line, Rectangle, Circle).
Future<void> selectBrushStyleViaUi(WidgetTester tester, BrushStyle style) async {
  final AppProvider appProvider = appProviderFromTester(tester);
  if (appProvider.brushStyle == style) {
    return;
  }
  await _settleToolPanel(tester);
  final Finder dropdown = find.byType(AppDropdown<int>);
  expect(dropdown, findsOneWidget, reason: 'Brush style dropdown should be shown');
  await tester.ensureVisible(dropdown.first);
  await tester.pump();
  await tapLikeHumanWithoutSettling(tester, tester.getCenter(dropdown.first));
  await pumpForDialogTransition(tester);

  final Finder item = find.text(brushStyleLabel(_l10n(tester), style));
  expect(item, findsAtLeastNWidgets(1), reason: 'Brush style "$style" should be listed');
  await tapLikeHumanWithoutSettling(tester, tester.getCenter(item.last));
  await pumpForDialogTransition(tester);
  expect(appProvider.brushStyle, style);
}

/// Sets the brush size through the tool panel's size slider.
Future<void> setBrushSizeViaSlider(WidgetTester tester, double size) async {
  final Finder slider = find.byKey(Keys.toolBrushSizeSlider);
  if (slider.evaluate().isEmpty) {
    appProviderFromTester(tester).brushSize = size;
    await tester.pump();
    return;
  }
  final Finder innerSlider = find.descendant(of: slider.first, matching: find.byType(AppSlider));
  final Offset sliderCenter = tester.getCenter(innerSlider.first);
  InteractionTracker.recordTap(sliderCenter);
  tester.widget<AppSlider>(innerSlider.first).onChanged?.call(size);
  await tester.pump();
}

/// Sets the smudge / blur-brush intensity through the tool panel's slider.
Future<void> setBrushIntensityViaSlider(WidgetTester tester, double intensity) async {
  final Finder slider = find.byKey(Keys.toolBrushIntensitySlider);
  expect(slider, findsAtLeastNWidgets(1), reason: 'Intensity slider should be shown');
  InteractionTracker.recordTap(tester.getCenter(slider.first));
  final AppSlider widget = tester.widget<AppSlider>(slider.first);
  widget.onChanged?.call(intensity);
  await tester.pump();
}

/// Sets the smudge / blur-brush intensity through the picker dialog opened by
/// the intensity row's button, then closes the dialog.
Future<void> setBrushIntensityViaPicker(WidgetTester tester, double intensity) async {
  await tapByKey(tester, Keys.toolBrushIntensityButton);
  final Finder picker = find.byType(BrushIntensityPicker);
  await pumpUntilIdle(tester, () => picker.evaluate().isNotEmpty);
  await pumpForDialogTransition(tester);
  final Finder slider = find.descendant(of: picker, matching: find.byType(AppSlider));
  InteractionTracker.recordTap(tester.getCenter(slider.first));
  tester.widget<AppSlider>(slider.first).onChanged?.call(intensity);
  await tester.pump();
  await captureShowcaseFrame(tester);
  Navigator.of(tester.element(picker)).pop();
  await pumpForDialogTransition(tester);
}

/// Opens the colour picker behind [previewKey], types [color] as hex, and
/// applies it — the same path a user takes to dial in an exact colour.
Future<void> pickColorViaDialog(
  WidgetTester tester, {
  required Key previewKey,
  required Color color,
}) async {
  final Finder preview = find.byKey(previewKey);
  expect(preview, findsAtLeastNWidgets(1), reason: 'Colour preview $previewKey should be visible');
  await tester.ensureVisible(preview.first);
  await tester.pump();
  await tapLikeHumanWithoutSettling(tester, tester.getCenter(preview.first));
  await pumpForDialogTransition(tester);

  final Finder dialog = find.byType(ColorPickerDialog);
  expect(dialog, findsOneWidget, reason: 'Colour picker should open');
  final Finder hexField = find.descendant(of: dialog, matching: find.byType(EditableText));
  await tester.enterText(hexField.last, colorToHexString(color));
  await tester.pump();
  await captureShowcaseFrame(tester);

  final Finder applyButton = find.descendant(
    of: dialog,
    matching: find.text(_l10n(tester).apply),
  );
  await tapLikeHumanWithoutSettling(tester, tester.getCenter(applyButton.last));
  await pumpForDialogTransition(tester);
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pump();
}

/// Picks the brush colour through the colour dialog.
Future<void> pickBrushColorViaUi(WidgetTester tester, Color color) =>
    pickColorViaDialog(tester, previewKey: Keys.toolPanelBrushColor1, color: color);

/// Opens the brush's Hatching sheet, dials in the pattern with its sliders and
/// cross-hatch switch, then closes the sheet. The active brush style must be
/// Hatch or Cross-hatch; the switch flips between the two.
Future<void> configureBrushHatchViaSheet(
  WidgetTester tester, {
  required int angleDegrees,
  required int spacing,
  required int lineWidth,
  required bool crossed,
}) async {
  await tapByKey(tester, Keys.toolBrushHatchButton);
  final Finder controls = find.byType(HatchSettingsControls);
  await pumpUntilIdle(tester, () => controls.evaluate().isNotEmpty);
  await pumpForDialogTransition(tester);

  for (final (Key key, int value) in <(Key, int)>[
    (Keys.hatchAngleSlider, angleDegrees),
    (Keys.hatchSpacingSlider, spacing),
    (Keys.hatchLineWidthSlider, lineWidth),
  ]) {
    final Finder slider = find.byKey(key);
    InteractionTracker.recordTap(tester.getCenter(slider));
    tester.widget<AppSlider>(slider).onChanged?.call(value.toDouble());
    await tester.pump();
  }
  final bool isCrossed = appProviderFromTester(tester).brushStyle == BrushStyle.crossHatch;
  if (isCrossed != crossed) {
    await tapByKey(tester, Keys.hatchCrossedToggle);
  }
  await captureShowcaseFrame(tester);

  Navigator.of(tester.element(controls)).pop();
  await pumpForDialogTransition(tester);
  expect(appProviderFromTester(tester).hatchPattern.spacing, spacing);
}

/// Turns the paint bucket's Halftone mode on or off and sets its dot size
/// with the inline slider. The paint bucket must be the active tool.
Future<void> setFillHalftoneViaUi(
  WidgetTester tester, {
  required bool enabled,
  int? dotSizePercent,
}) async {
  final AppProvider appProvider = appProviderFromTester(tester);
  if (appProvider.fillModel.halftoneEnabled != enabled) {
    await tapByKey(tester, Keys.toolFillHalftoneToggle);
  }
  expect(appProvider.fillModel.halftoneEnabled, enabled, reason: 'Halftone toggle should follow the switch');
  if (dotSizePercent != null) {
    final Finder slider = find.byKey(Keys.toolFillHalftoneSlider);
    InteractionTracker.recordTap(tester.getCenter(slider));
    tester.widget<AppSlider>(slider).onChanged?.call(dotSizePercent.toDouble());
    await tester.pump();
    expect(appProvider.fillModel.halftoneMaxDotSizePercent, dotSizePercent);
  }
}

/// Sets the Text tool's font size through its font-size slider.
Future<void> setTextSizeViaUi(WidgetTester tester, double size) async {
  final String label = _l10n(tester).fontSizeLabel;
  final Finder picker = find.byWidgetPredicate((Widget widget) => widget is BrushSizePicker && widget.title == label);
  expect(picker, findsOneWidget, reason: 'Text tool font-size control should be shown');
  InteractionTracker.recordTap(tester.getCenter(picker));
  tester.widget<BrushSizePicker>(picker).onChanged(size);
  await tester.pump();
  expect(appProviderFromTester(tester).textToolState.size, size);
}

/// Waits until every painted, non-text layer's display cache has been rebuilt
/// at full resolution for the current zoom, so a capture is pixel-sharp.
Future<void> waitForSharpDisplayCaches(WidgetTester tester) async {
  final LayersProvider layers = layersProviderFromTester(tester);
  bool isSharp(LayerProvider layer) =>
      layer.actionStack.isEmpty ||
      layer.actionStack.any((UserActionDrawing action) => action.textObject != null) ||
      layer.displayCacheScale >= AppMath.one - _sharpCacheEpsilon;
  layers.repaintCanvas();
  final bool sharp = await pumpUntilIdle(tester, () {
    layers.repaintCanvas();
    return layers.list.every(isSharp);
  });
  expect(
    sharp,
    isTrue,
    reason:
        'Layer display caches should reach full resolution: '
        '${layers.list.map((LayerProvider layer) => '${layer.name}=${layer.displayCacheScale}').join(', ')}',
  );
}

/// Arms [effect] as a brush from the Brush section and sets its sliders.
Future<void> armEffectBrushViaUi(
  WidgetTester tester,
  SelectionEffect effect, {
  required double strength,
  required double brushSize,
}) async {
  final AppProvider appProvider = appProviderFromTester(tester);
  if (appProvider.effectBrushModel.effect != effect) {
    await tapByKey(tester, ValueKey<SelectionEffect>(effect));
  }
  expect(appProvider.effectBrushModel.effect, effect, reason: 'Effect $effect should be armed');

  final AppSlider sizeSlider = tester.widget<AppSlider>(find.byKey(Keys.effectPaintSizeSlider).first);
  sizeSlider.onChanged?.call(brushSize);
  await tester.pump();
  final AppSlider strengthSlider = tester.widget<AppSlider>(find.byKey(Keys.effectPaintStrengthSlider).first);
  strengthSlider.onChanged?.call(strength);
  await tester.pump();
}

/// Disarms the currently armed effect brush by tapping its button again.
Future<void> disarmEffectBrushViaUi(WidgetTester tester) async {
  final SelectionEffect? effect = appProviderFromTester(tester).effectBrushModel.effect;
  if (effect != null) {
    await tapByKey(tester, ValueKey<SelectionEffect>(effect));
  }
}

// ---------------------------------------------------------------------------
// Strokes
// ---------------------------------------------------------------------------

/// Paints one stroke through [canvasPoints] with the active tool, then waits
/// for any async commit (smudge, blur brush, effect brush) to land.
Future<void> paintCanvasStroke(
  WidgetTester tester,
  List<Offset> canvasPoints, {
  bool captureFrame = true,
}) async {
  expect(canvasPoints.length, greaterThanOrEqualTo(AppMath.pair), reason: 'A stroke needs two points');
  final List<Offset> screenPoints = <Offset>[
    for (final Offset point in canvasPoints) canvasToScreen(tester, point),
  ];
  InteractionTracker.recordDrag(screenPoints.first, screenPoints.last);

  final TestGesture gesture = await tester.startGesture(
    screenPoints.first,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );
  await tester.pump(_strokeMovePump);
  for (final Offset point in screenPoints.skip(1)) {
    await gesture.moveTo(point);
    await tester.pump(_strokeMovePump);
  }
  await gesture.up();
  await tester.pump();
  await waitForPixelBrushCommit(tester);
  if (captureFrame) {
    await captureShowcaseFrame(tester);
  } else {
    InteractionTracker.clear();
  }
}

/// Paints a two-point drag (line, rectangle, circle tools) in canvas space.
Future<void> dragCanvasShape(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
  bool captureFrame = true,
}) async {
  final Offset start = canvasToScreen(tester, from);
  final Offset end = canvasToScreen(tester, to);
  InteractionTracker.recordDrag(start, end);
  final TestGesture gesture = await tester.startGesture(
    start,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );
  await tester.pump(_strokeMovePump);
  for (int step = 1; step <= _handleDragSteps; step++) {
    await gesture.moveTo(Offset.lerp(start, end, step / _handleDragSteps)!);
    await tester.pump(_strokeMovePump);
  }
  await gesture.up();
  await tester.pump();
  if (captureFrame) {
    await captureShowcaseFrame(tester);
  } else {
    InteractionTracker.clear();
  }
}

/// Clicks each vertex of a straight-edge selection and closes it on the first.
Future<void> selectPolygonViaUi(
  WidgetTester tester,
  List<Offset> canvasPoints,
) async {
  // Dragging inside a live marquee moves it, so start every new shape fresh.
  await clearSelectionViaUi(tester);
  await selectLineRegion(
    tester,
    points: <Offset>[for (final Offset point in canvasPoints) canvasToScreen(tester, point)],
  );
}

/// Draws a free-form lasso through [canvasPoints].
Future<void> selectLassoViaUi(
  WidgetTester tester,
  List<Offset> canvasPoints,
) async {
  // Dragging inside a live marquee moves it, so start every new shape fresh.
  await clearSelectionViaUi(tester);
  await selectLassoArea(
    tester,
    points: <Offset>[
      for (final Offset point in canvasPoints) canvasToScreen(tester, point),
      canvasToScreen(tester, canvasPoints.first),
    ],
  );
}

/// Drags a rectangular marquee between two canvas points.
Future<void> selectRectangleViaUi(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
}) async {
  // Dragging inside a live marquee moves it, so start every new shape fresh.
  await clearSelectionViaUi(tester);
  await selectRectangleArea(
    tester,
    startPosition: canvasToScreen(tester, from),
    endPosition: canvasToScreen(tester, to),
  );
}

/// Clears the current selection with the shell's Cancel Selection control.
Future<void> clearSelectionViaUi(WidgetTester tester) async {
  final AppProvider appProvider = appProviderFromTester(tester);
  if (!appProvider.selectorModel.isVisible) {
    return;
  }
  final Finder cancel = find.byKey(Keys.toolSelectorCancel).hitTestable();
  if (cancel.evaluate().isNotEmpty) {
    await tapByKey(tester, Keys.toolSelectorCancel);
  } else {
    appProvider.selectorModel.clear();
    appProvider.update();
  }
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Paint bucket
// ---------------------------------------------------------------------------

/// Taps the paint bucket at [canvasPoint] in solid mode and, when
/// [toleranceDragDx] is given, scrubs horizontally to widen the tolerance
/// before releasing — the wand-style tap + drag gesture.
Future<void> solidFillViaUi(
  WidgetTester tester, {
  required Offset canvasPoint,
  required Color color,
  double? toleranceDragDx,
}) async {
  final AppProvider appProvider = appProviderFromTester(tester);
  await tapByKey(tester, Keys.toolFill);
  await tapByKey(tester, Keys.toolFillModeSolid);
  appProvider.fillColor = color;
  await tester.pump();

  final int actionCountBefore = appProvider.layers.selectedLayer.actionStack.length;
  final Offset screenPoint = canvasToScreen(tester, canvasPoint);
  InteractionTracker.recordTap(screenPoint);
  final TestGesture gesture = await tester.startGesture(
    screenPoint,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );
  await pumpUntilIdle(tester, () => appProvider.fillPreviewAction != null);

  if (toleranceDragDx != null) {
    for (int step = 1; step <= _handleDragSteps; step++) {
      await gesture.moveTo(screenPoint + Offset(toleranceDragDx * step / _handleDragSteps, 0));
      await tester.pump(_strokeMovePump);
    }
    InteractionTracker.recordDrag(screenPoint, screenPoint + Offset(toleranceDragDx, 0));
    await pumpUntilIdle(tester, () => appProvider.fillPreviewAction != null);
    await captureShowcaseFrame(tester);
  }

  await gesture.up();
  await tester.pump();
  final bool committed = await pumpUntilIdle(
    tester,
    () => appProvider.layers.selectedLayer.actionStack.length > actionCountBefore,
  );
  expect(committed, isTrue, reason: 'Solid fill should commit one action');
  await captureShowcaseFrame(tester);
}

/// Runs a gradient paint-bucket session entirely through the UI: tap to seed
/// the handles, drag both endpoint handles to [start] / [end], then Apply.
///
/// Stop colours and positions are seeded on the fill model (the tool panel's
/// colour-stop editor), as in [performFloodFillGradient].
Future<void> gradientFillViaUi(
  WidgetTester tester, {
  required FillMode mode,
  required Offset tapPoint,
  required Offset start,
  required Offset end,
  required List<Color> colors,
  required List<double> stops,
}) async {
  expect(colors.length, stops.length, reason: 'Every gradient colour needs a stop');
  final AppProvider appProvider = appProviderFromTester(tester);
  await tapByKey(tester, Keys.toolFill);
  await tapByKey(tester, mode == FillMode.radial ? Keys.toolFillModeRadial : Keys.toolFillModeLinear);

  appProvider.fillModel.gradientStopColors
    ..clear()
    ..addAll(colors);
  appProvider.fillModel.gradientStopPositions
    ..clear()
    ..addAll(stops);
  appProvider.update();
  await tester.pump();

  final int actionCountBefore = appProvider.layers.selectedLayer.actionStack.length;
  await tapLikeHumanWithoutSettling(tester, canvasToScreen(tester, tapPoint));
  final bool previewed = await pumpUntilIdle(tester, () => appProvider.fillPreviewAction != null);
  expect(previewed, isTrue, reason: 'Gradient tap should open a preview session');

  // The session's Apply/Cancel controls sit just below the gradient centre and
  // can cover a knob once the other end moves, so place the end knob first and
  // re-check both, retrying whichever one the controls blocked.
  final int lastHandle = colors.length - AppMath.one;
  bool isOnTarget(GradientPoint point, Offset target) =>
      (appProvider.toCanvas(point.offset) - target).distance < _gradientHandleCanvasTolerance;
  for (int attempt = 0; attempt < _gradientHandlePlacementAttempts; attempt++) {
    if (!isOnTarget(appProvider.fillModel.gradientPoints.last, end)) {
      await _dragGradientHandleTo(tester, handleIndex: lastHandle, canvasTarget: end);
    }
    if (!isOnTarget(appProvider.fillModel.gradientPoints.first, start)) {
      await _dragGradientHandleTo(tester, handleIndex: 0, canvasTarget: start);
    }
  }
  expect(isOnTarget(appProvider.fillModel.gradientPoints.first, start), isTrue, reason: 'Gradient start handle placed');
  expect(isOnTarget(appProvider.fillModel.gradientPoints.last, end), isTrue, reason: 'Gradient end handle placed');
  // Each handle move re-resolves the preview asynchronously and only the
  // newest request may land; resolve once more for the settled handles so
  // Apply commits exactly what the overlay ends on.
  await tester.runAsync(appProvider.updateGradientPreview);
  await tester.pump();
  await captureShowcaseFrame(tester);

  await tapByKey(tester, Keys.fillApply);
  final bool committed = await pumpUntilIdle(
    tester,
    () => appProvider.layers.selectedLayer.actionStack.length > actionCountBefore,
  );
  expect(committed, isTrue, reason: 'Applying the gradient should commit one action');
}

Future<void> _dragGradientHandleTo(
  WidgetTester tester, {
  required int handleIndex,
  required Offset canvasTarget,
}) async {
  final Finder handle = find.byKey(Key('${Keys.gradientHandleKeyPrefixText}$handleIndex'));
  expect(handle, findsOneWidget, reason: 'Gradient handle $handleIndex should be shown');
  final Offset from = tester.getCenter(handle);
  final Offset to = canvasToScreen(tester, canvasTarget);
  InteractionTracker.recordDrag(from, to);
  final TestGesture gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await tester.pump(_strokeMovePump);
  for (int step = 1; step <= _handleDragSteps; step++) {
    await gesture.moveTo(Offset.lerp(from, to, step / _handleDragSteps)!);
    await tester.pump(_strokeMovePump);
  }
  // Drag slop swallows the first pixels of the pan; keep following the knob
  // with the pointer until it sits on the target, as a person would.
  for (int correction = 0; correction < _handleCorrectionMaxSteps; correction++) {
    final Offset remaining = to - tester.getCenter(handle);
    if (remaining.distance < _handleTargetTolerance) {
      break;
    }
    await gesture.moveBy(remaining);
    await tester.pump(_strokeMovePump);
  }
  await gesture.up();
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Eyedropper and viewport
// ---------------------------------------------------------------------------

/// Alt-clicks [canvasPoint] to sample the composite colour into the brush.
Future<Color> eyedropBrushColorViaUi(WidgetTester tester, Offset canvasPoint) async {
  final AppProvider appProvider = appProviderFromTester(tester);
  final Color before = appProvider.brushColor;
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.pump();
  await tapLikeHumanWithoutSettling(tester, canvasToScreen(tester, canvasPoint));
  await pumpUntilIdle(tester, () => !_sameColor(appProvider.brushColor, before));
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pump();
  return appProvider.brushColor;
}

bool _sameColor(Color a, Color b) {
  int channel(double value) => (value * AppLimits.rgbChannelMax).round();
  return (channel(a.r) - channel(b.r)).abs() <= _eyedropChannelTolerance &&
      (channel(a.g) - channel(b.g)).abs() <= _eyedropChannelTolerance &&
      (channel(a.b) - channel(b.b)).abs() <= _eyedropChannelTolerance;
}

/// Pinch-zooms with a trackpad gesture around [canvasFocus] so the view
/// scale is multiplied by [scale].
///
/// Flutter reports `PointerPanZoomUpdateEvent.scale` cumulatively since the
/// gesture began, and the canvas applies each update's scale as a factor, so
/// the per-gesture zoom is the product of the cumulative values. The ramp
/// base is chosen so that product lands on [scale].
Future<void> trackpadZoomViaUi(
  WidgetTester tester, {
  required Offset canvasFocus,
  required double scale,
}) async {
  final Offset focal = canvasToScreen(tester, canvasFocus);
  final double rampBase = math.pow(scale, AppMath.pair / (_pinchUpdateSteps + AppMath.one)).toDouble();
  final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.trackpad);
  await gesture.panZoomStart(focal);
  await tester.pump();
  for (int step = 1; step <= _pinchUpdateSteps; step++) {
    await gesture.panZoomUpdate(focal, scale: math.pow(rampBase, step / _pinchUpdateSteps).toDouble());
    await tester.pump(_strokeMovePump);
  }
  await gesture.panZoomEnd();
  await tester.pump();
  await captureShowcaseFrame(tester);
}

/// Two-finger trackpad pan by [screenDelta].
Future<void> trackpadPanViaUi(
  WidgetTester tester, {
  required Offset canvasFocus,
  required Offset screenDelta,
}) async {
  final Offset focal = canvasToScreen(tester, canvasFocus);
  final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.trackpad);
  await gesture.panZoomStart(focal);
  await tester.pump();
  for (int step = 1; step <= _pinchUpdateSteps; step++) {
    await gesture.panZoomUpdate(focal, pan: screenDelta * (step / _pinchUpdateSteps));
    await tester.pump(_strokeMovePump);
  }
  await gesture.panZoomEnd();
  await tester.pump();
  await captureShowcaseFrame(tester);
}

/// Restores the fitted, centred view with the floating Center button.
Future<void> fitCanvasViaUi(WidgetTester tester) async {
  await prepareCanvasViewport(tester);
  await tester.pump();
}

/// Shows the canvas at exactly 100 % zoom, centred in the canvas area, and
/// waits for every layer to re-rasterize at that resolution — so strokes,
/// video frames and exports are pixel-sharp rather than resampled.
Future<void> showActualSizeCentered(WidgetTester tester) async {
  final AppProvider appProvider = appProviderFromTester(tester);
  final Size viewSize = tester.getSize(find.byType(CanvasGestureHandler));
  appProvider.resetView();
  appProvider.canvasOffset = Offset(
    (viewSize.width - appProvider.layers.width) / AppMath.pair,
    (viewSize.height - appProvider.layers.height) / AppMath.pair,
  );
  appProvider.update();
  await pumpForUnitTestUiSettle(tester);
  await waitForSharpDisplayCaches(tester);
}

// ---------------------------------------------------------------------------
// Layers
// ---------------------------------------------------------------------------

/// Adds a layer above the selected one with the layer row's add button and
/// renames it through the rename dialog.
Future<void> addLayerViaUi(WidgetTester tester, String name) async {
  final LayersProvider layers = layersProviderFromTester(tester);
  final int countBefore = layers.length;
  await tapByKey(tester, Keys.layerAddAboveButton);
  final bool added = await pumpUntilIdle(tester, () => layers.length > countBefore);
  expect(added, isTrue, reason: 'Add layer should insert one layer');
  await renameSelectedLayerViaUi(tester, name);
}

/// Renames the selected layer: long-press its name, type, apply.
Future<void> renameSelectedLayerViaUi(WidgetTester tester, String name) async {
  final LayersProvider layers = layersProviderFromTester(tester);
  final Finder nameText = find.text(layers.selectedLayer.name);
  expect(nameText, findsAtLeastNWidgets(1), reason: 'Selected layer name should be visible');
  await tester.ensureVisible(nameText.first);
  await tester.pump();
  await tester.longPress(nameText.first);
  await pumpForDialogTransition(tester);

  final Finder field = find.byKey(Keys.layerRenameTextField);
  expect(field, findsOneWidget, reason: 'Rename dialog should open');
  await tester.enterText(field, name);
  await tester.pump();
  await tapByKey(tester, Keys.layerRenameApplyButton);
  await pumpForDialogTransition(tester);
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pump();
  expect(layers.selectedLayer.name, name);
}

/// Arms the Layers panel's picker puck, presses at [canvasPoint], nudges the
/// puck into place and releases: the layer owning that pixel gets selected.
Future<String> pickLayerWithPuckViaUi(WidgetTester tester, Offset canvasPoint) async {
  final LayersProvider layers = layersProviderFromTester(tester);
  await tapByKey(tester, Keys.layerPickerToggleButton);
  final Offset target = canvasToScreen(tester, canvasPoint);
  final Offset press = target - const Offset(_pickerNudge, _pickerNudge);
  InteractionTracker.recordDrag(press, target);
  final TestGesture gesture = await tester.startGesture(press, kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await tester.pump(_strokeMovePump);
  await gesture.moveTo(target);
  await tester.pump(_strokeMovePump);
  await captureShowcaseFrame(tester);
  final int before = layers.selectedLayerIndex;
  await gesture.up();
  await pumpUntilIdle(tester, () => layers.selectedLayerIndex != before);
  await pumpForUnitTestUiSettle(tester);
  return layers.selectedLayer.name;
}

/// Shift+Alt-clicks [canvasPoint]: the keyboard shortcut for picking the layer
/// that owns the pixel under the pointer.
Future<String> pickLayerWithShortcutViaUi(WidgetTester tester, Offset canvasPoint) async {
  final LayersProvider layers = layersProviderFromTester(tester);
  final int before = layers.selectedLayerIndex;
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.pump();
  await tapLikeHumanWithoutSettling(tester, canvasToScreen(tester, canvasPoint));
  await pumpUntilIdle(tester, () => layers.selectedLayerIndex != before);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await pumpForUnitTestUiSettle(tester);
  return layers.selectedLayer.name;
}

/// Edge-detection wand with the tap-then-scrub gesture: press at
/// [canvasPoint] and drag horizontally by [toleranceDragDx] screen pixels to
/// widen the colour tolerance live before releasing.
Future<void> selectWandWithToleranceDragViaUi(
  WidgetTester tester, {
  required Offset canvasPoint,
  required double toleranceDragDx,
}) async {
  final AppProvider appProvider = appProviderFromTester(tester);
  await clearSelectionViaUi(tester);
  await activateSelectorTool(tester);
  await tapByKey(tester, Keys.toolSelectorModeWand);
  final int toleranceBefore = appProvider.tolerance;
  final Offset start = canvasToScreen(tester, canvasPoint);
  final TestGesture gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await pumpUntilIdle(tester, () => !appProvider.wandSelection.isInProgress);
  for (int step = 1; step <= _handleDragSteps; step++) {
    await gesture.moveTo(start + Offset(toleranceDragDx * step / _handleDragSteps, 0));
    await tester.pump(_strokeMovePump);
  }
  InteractionTracker.recordDrag(start, start + Offset(toleranceDragDx, 0));
  await captureShowcaseFrame(tester);
  await gesture.up();
  await pumpUntilIdle(
    tester,
    () => !appProvider.wandSelection.isInProgress && !appProvider.wandSelection.hasPendingRequest,
  );
  expect(appProvider.selectorModel.isVisible, isTrue, reason: 'The wand should leave a selection');
  expect(appProvider.tolerance, isNot(toleranceBefore), reason: 'Scrubbing should change the tolerance');
}

/// Selects a layer by tapping its row thumbnail.
Future<void> selectLayerViaUi(WidgetTester tester, String name) async {
  final LayersProvider layers = layersProviderFromTester(tester);
  final int index = layers.list.indexWhere((LayerProvider layer) => layer.name == name);
  expect(index, isNonNegative, reason: 'Layer "$name" should exist');
  if (layers.selectedLayerIndex == index) {
    return;
  }
  final Finder label = find.text(name);
  await tester.ensureVisible(label.first);
  await tester.pump();
  await tapLikeHuman(tester, tester.getCenter(label.first));
  if (layers.selectedLayerIndex != index) {
    layers.selectedLayerIndex = index;
    await tester.pump();
  }
}

/// Scrubs the layer thumbnail horizontally to set the layer [opacity].
Future<void> setLayerOpacityViaUi(
  WidgetTester tester, {
  required String layerName,
  required double opacity,
}) async {
  final LayersProvider layers = layersProviderFromTester(tester);
  final int index = layers.list.indexWhere((LayerProvider layer) => layer.name == layerName);
  expect(index, isNonNegative, reason: 'Layer "$layerName" should exist');
  final LayerProvider layer = layers.get(index);

  final Finder thumbnail = find.byWidgetPredicate(
    (Widget widget) => widget is LayerThumbnail && identical(widget.layer, layer),
  );
  expect(thumbnail, findsOneWidget, reason: 'Thumbnail for "$layerName" should be visible');
  await tester.ensureVisible(thumbnail);
  await tester.pump();

  // Scrub like a person watching the percentage readout: keep nudging the
  // drag until the live value lands on the target (drag slop eats the first
  // few pixels, so an open-loop distance would undershoot).
  final Offset from = tester.getCenter(thumbnail);
  final TestGesture gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await tester.pump();
  Offset position = from;
  for (int step = 0; step < _opacityScrubMaxSteps; step++) {
    final double remaining = opacity - layer.opacity;
    if (remaining.abs() < AppMath.tinyPercentage) {
      break;
    }
    position += Offset(remaining.sign * _opacityScrubStepPixels, 0);
    await gesture.moveTo(position);
    await tester.pump();
  }
  InteractionTracker.recordDrag(from, position);
  await gesture.up();
  await pumpForUnitTestUiSettle(tester);
  await captureShowcaseFrame(tester);
  expect(layer.opacity, closeTo(opacity, AppMath.tinyPercentage * AppMath.pair));
}

/// Merges the selected layer into the one below with the layer row's
/// "Merge below" button, then names the merged layer [mergedName].
Future<void> mergeSelectedLayerDownViaUi(WidgetTester tester, {required String mergedName}) async {
  final LayersProvider layers = layersProviderFromTester(tester);
  final AppLocalizations l10n = _l10n(tester);
  final int countBefore = layers.length;
  final Finder button = find.byWidgetPredicate(
    (Widget widget) => widget is AppTooltip && widget.message == l10n.layerMergeBelow,
  );
  expect(button, findsOneWidget, reason: 'Merge below should be offered on the selected layer');
  await tester.ensureVisible(button);
  await tester.pump();
  await tapLikeHumanWithoutSettling(tester, tester.getCenter(button));
  final bool merged = await pumpUntilIdle(tester, () => layers.length < countBefore);
  expect(merged, isTrue, reason: 'Merge below should remove one layer');
  await renameSelectedLayerViaUi(tester, mergedName);
}

/// Picks [description]'s blend mode for the selected layer from the row's
/// blend-mode button menu.
Future<void> setSelectedLayerBlendModeViaUi(
  WidgetTester tester, {
  required BlendMode blendMode,
  required String description,
}) async {
  final AppLocalizations l10n = _l10n(tester);
  final Finder button = find.byWidgetPredicate(
    (Widget widget) => widget is AppTooltip && widget.message.startsWith(l10n.layerBlendMode),
  );
  expect(button, findsAtLeastNWidgets(1), reason: 'Blend mode button should be visible');
  await tester.ensureVisible(button.first);
  await tester.pump();
  await tapLikeHumanWithoutSettling(tester, tester.getCenter(button.first));
  final Finder item = find.text(description);
  await pumpUntilIdle(tester, () => item.evaluate().isNotEmpty);
  await pumpForDialogTransition(tester);

  expect(item, findsAtLeastNWidgets(1), reason: 'Blend menu should list "$description"');
  await tester.ensureVisible(item.last);
  await tester.pump();
  await tapLikeHumanWithoutSettling(tester, tester.getCenter(item.last));
  await pumpForDialogTransition(tester);
  expect(layersProviderFromTester(tester).selectedLayer.blendMode, blendMode);
}

/// Applies [hatchMarks] for the hatch-marks brush style.
void applyHatchMarks(WidgetTester tester, HatchMarks hatchMarks) {
  appProviderFromTester(tester).hatchMarks = hatchMarks;
}

/// The brush colour currently configured.
Color currentBrushColor(WidgetTester tester) => appProviderFromTester(tester).brushColor;

/// Whether [action] is the currently selected gesture tool.
bool isActionSelected(WidgetTester tester, ToolKind action) => appProviderFromTester(tester).selectedTool == action;
