// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/file_jpeg.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/files/file_webp.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/services/fill_service.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:fpaint/widgets/nine_grid_selector.dart';
import 'package:image/image.dart' as img;

/// Number of incremental steps used in human-like drag gestures.
const double _humanDragSteps = 3;

/// Device pixel ratio used for unit test screenshots.
const double _unitTestDevicePixelRatio = 1.0;

/// Base output directory for generated unit test artifacts.
const String _unitTestOutputDirectoryPath = 'test/output';

/// Subdirectory for unit test screenshot output within [_unitTestOutputDirectoryPath].
const String _unitTestScreenshotDirectoryName = 'screenshots';

/// Subdirectory for video frame output within the screenshot directory.
const String _videoFrameSubdirectoryName = 'video_frames';

/// Prefix for video frame filenames.
const String _videoFrameFilenamePrefix = 'frame_';

/// File extension for video frame images.
const String _videoFrameFileExtension = 'png';

/// Filename for the assembled MP4 video.
const String _videoOutputFilename = 'unit_test_video.mp4';

/// Frames per second for the assembled video.
const int _videoFramesFps = 30;

/// Width of the zero-padded frame index in filenames.
const int _videoFrameIndexPadding = 6;

// ---------------------------------------------------------------------------
// UI interaction string constants (must match production widget strings)
// ---------------------------------------------------------------------------

/// Tooltip on the add-layer button in [LayerSelector].
const String _uiTooltipAddLayerAbove = 'Add a layer above';

/// Button label in the layer rename dialog.
const String _uiDialogApply = 'Apply';

/// Tooltip on the main hamburger menu.
const String _uiMenuTooltip = 'Menu';

/// Menu item text for canvas settings (l10n.canvas in English).
const String _uiMenuCanvasSettings = 'Canvas...';

// ---------------------------------------------------------------------------
// Interaction overlay constants
// ---------------------------------------------------------------------------

/// Outer radius of the tap indicator circle.
const double _tapIndicatorRadius = 18.0;

/// Length of each crosshair arm extending from the tap centre.
const double _tapCrosshairLength = 24.0;

/// Stroke width of tap indicator outlines.
const double _tapIndicatorStrokeWidth = 2.5;

/// Inner dot radius drawn at the exact tap point.
const double _tapDotRadius = 4.0;

/// Stroke width of the drag indicator line.
const double _dragIndicatorStrokeWidth = 2.5;

/// Radius of the small circle at the drag start point.
const double _dragStartCircleRadius = 6.0;

/// Length of the arrowhead sides at the drag end point.
const double _dragArrowHeadLength = 14.0;

/// Half-angle (in radians) of the arrowhead opening.
const double _dragArrowHeadAngle = math.pi / 6;

/// Primary colour of tap indicators (red with some transparency).
const Color _tapIndicatorColor = Color.fromARGB(200, 255, 50, 50);

/// Primary colour of drag indicators (blue with some transparency).
const Color _dragIndicatorColor = Color.fromARGB(200, 50, 120, 255);

/// White outline drawn behind indicators for contrast on any background.
const Color _indicatorOutlineColor = Color.fromARGB(160, 255, 255, 255);

/// Stroke width of the contrast outline behind indicators.
const double _indicatorOutlineWidth = 4.0;

// ---------------------------------------------------------------------------
// Interaction tracking
// ---------------------------------------------------------------------------

/// Describes one recorded user interaction for overlay rendering.
class InteractionRecord {
  InteractionRecord.tap(this.position) : endPosition = null, type = InteractionType.tap;

  InteractionRecord.drag(this.position, this.endPosition) : type = InteractionType.drag;

  /// Screen-space position of the interaction (tap point or drag start).
  final Offset position;

  /// Screen-space end position for drag interactions; `null` for taps.
  final Offset? endPosition;

  /// Whether this is a tap or drag.
  final InteractionType type;
}

/// The kind of user interaction being recorded.
enum InteractionType {
  /// A single-point tap or click.
  tap,

  /// A drag gesture from one point to another.
  drag,
}

/// Collects [InteractionRecord]s so the video recorder can draw overlays.
class InteractionTracker {
  InteractionTracker._();

  static final List<InteractionRecord> _records = <InteractionRecord>[];

  /// All interactions recorded since the last [clear].
  static List<InteractionRecord> get records => List<InteractionRecord>.unmodifiable(_records);

  /// Records a tap at [position].
  static void recordTap(Offset position) => _records.add(InteractionRecord.tap(position));

  /// Records a drag from [start] to [end].
  static void recordDrag(Offset start, Offset end) => _records.add(InteractionRecord.drag(start, end));

  /// Removes all recorded interactions.
  static void clear() => _records.clear();
}

// ---------------------------------------------------------------------------
// Viewport
// ---------------------------------------------------------------------------

/// Configures the test viewport to the integration-test tablet landscape size.
void configureTestViewport(final WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.devicePixelRatio = _unitTestDevicePixelRatio;
  tester.view.physicalSize = const Size(
    AppLayout.integrationTestTabletLandscapeWidth,
    AppLayout.integrationTestTabletLandscapeHeight,
  );
}

/// Centers and zooms the canvas to fit the viewport.
Future<void> prepareCanvasViewport(final WidgetTester tester) async {
  final Finder centerButton = find.byKey(Keys.floatActionCenter);
  if (centerButton.evaluate().isNotEmpty) {
    await tapByKey(tester, Keys.floatActionCenter);
  }

  final Finder zoomOutButton = find.byKey(Keys.floatActionZoomOut);
  if (zoomOutButton.evaluate().isNotEmpty) {
    await tapByKey(tester, Keys.floatActionZoomOut);
  }
}

// ---------------------------------------------------------------------------
// Gesture helpers
// ---------------------------------------------------------------------------

/// Simulates a human-like drag from [start] to [end] in incremental steps.
Future<void> dragLikeHuman(
  final WidgetTester tester,
  final Offset start,
  final Offset end,
) async {
  InteractionTracker.recordDrag(start, end);

  final TestGesture gesture = await tester.startGesture(
    start,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );

  final Offset stepDelta = (end - start) / _humanDragSteps;
  for (int i = 0; i < _humanDragSteps; i++) {
    await gesture.moveBy(stepDelta);
  }

  await gesture.up();
  await tester.pump();
}

/// Simulates a simple mouse tap at [position].
///
/// When a [UnitTestVideoRecorder] is active, a frame with a red target
/// overlay is automatically captured after the tap.
Future<void> tapLikeHuman(
  final WidgetTester tester,
  final Offset position,
) async {
  InteractionTracker.recordTap(position);

  final TestGesture gesture = await tester.startGesture(
    position,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );
  await gesture.up();
  await UnitTestVideoRecorder.captureAfterInteraction(tester);
}

/// Finds the widget matching [key] and taps it.
///
/// When a [UnitTestVideoRecorder] is active, a frame with a red target
/// overlay is automatically captured after the tap.
Future<void> tapByKey(final WidgetTester tester, final Key key) async {
  final Finder found = find.byKey(key);
  expect(found, findsOneWidget, reason: 'Should find button with key: $key');
  InteractionTracker.recordTap(tester.getCenter(found.first));
  await tester.tap(found.first);
  await tester.pump();
  await UnitTestVideoRecorder.captureAfterInteraction(tester);
}

/// Finds the widget matching [tooltip] and taps it.
Future<void> tapByTooltip(
  final WidgetTester tester,
  final String tooltip,
) async {
  final Finder found = find.byTooltip(tooltip);
  expect(found, findsOneWidget, reason: 'Should find widget with tooltip: $tooltip');
  await tapLikeHuman(tester, tester.getCenter(found.first));
  await tester.pump();
}

/// Drags the widget identified by [tooltip] by [delta].
Future<void> dragByTooltip(
  final WidgetTester tester, {
  required final String tooltip,
  required final Offset delta,
}) async {
  final Finder found = find.byTooltip(tooltip);
  expect(found, findsOneWidget, reason: 'Should find draggable widget with tooltip: $tooltip');
  final Offset start = tester.getCenter(found.first);
  await dragLikeHuman(tester, start, start + delta);
  await tester.pump();
}

/// Selects a rectangular area on the canvas.
Future<void> selectRectangleArea(
  final WidgetTester tester, {
  required final Offset startPosition,
  required final Offset endPosition,
}) async {
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  await tapByKey(tester, Keys.toolSelectorModeRectangle);
  await tester.pump();

  await dragLikeHuman(tester, startPosition, endPosition);
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Drawing helpers
// ---------------------------------------------------------------------------

/// Sets the brush size directly via [AppProvider].
Future<void> setBrushSizeViaProvider(
  final WidgetTester tester,
  final double brushSize,
) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  appProvider.brushSize = brushSize;
  await tester.pump();
}

/// Configures brush and fill colors on [AppProvider] if provided.
Future<void> _applyBrushAndFillColors(
  final WidgetTester tester, {
  final Color? brushColor,
  final Color? fillColor,
}) async {
  if (brushColor == null && fillColor == null) {
    return;
  }

  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context);

  if (brushColor != null) {
    appProvider.brushColor = brushColor;
  }
  if (fillColor != null) {
    appProvider.fillColor = fillColor;
  }
}

Future<void> _tapIconButtonBySvgKey(
  final WidgetTester tester,
  final String iconKey,
) async {
  final Finder iconFinder = find.byKey(ValueKey<String>(iconKey));
  final Finder buttonFinder = find.ancestor(of: iconFinder, matching: find.byType(IconButton));
  await tester.tap(buttonFinder.first);
}

/// Draws a line from [startPosition] to [endPosition] using human-like gestures.
Future<void> drawLineWithHumanGestures(
  final WidgetTester tester, {
  required final Offset startPosition,
  required final Offset endPosition,
  final double? brushSize,
  final Color? brushColor,
  final Color? fillColor,
}) async {
  if (brushSize != null) {
    await setBrushSizeViaProvider(tester, brushSize);
  }
  await _applyBrushAndFillColors(tester, brushColor: brushColor, fillColor: fillColor);

  await _tapIconButtonBySvgKey(tester, 'app_icon_lineAxis');
  await tester.pump();

  await dragLikeHuman(tester, startPosition, endPosition);
}

/// Draws a rectangle from [startPosition] to [endPosition] using human-like gestures.
Future<void> drawRectangleWithHumanGestures(
  final WidgetTester tester, {
  required final Offset startPosition,
  required final Offset endPosition,
  final double? brushSize,
  final Color? brushColor,
  final Color? fillColor,
}) async {
  if (brushSize != null) {
    await setBrushSizeViaProvider(tester, brushSize);
  }
  await _applyBrushAndFillColors(tester, brushColor: brushColor, fillColor: fillColor);

  await _tapIconButtonBySvgKey(tester, 'app_icon_cropSquare');
  await tester.pump();

  final TestGesture gesture = await tester.startGesture(
    startPosition,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );

  final Offset stepDelta = (endPosition - startPosition) / _humanDragSteps;
  for (int i = 0; i < _humanDragSteps; i++) {
    await gesture.moveBy(stepDelta);
    await tester.pump();
  }

  await gesture.up();
  await tester.pump();
}

/// Draws a circle centered at [center] with the given [radius].
Future<void> drawCircleWithHumanGestures(
  final WidgetTester tester, {
  required final Offset center,
  required final double radius,
  final double? brushSize,
  final Color? brushColor,
  final Color? fillColor,
}) async {
  if (brushSize != null) {
    await setBrushSizeViaProvider(tester, brushSize);
  }
  await _applyBrushAndFillColors(tester, brushColor: brushColor, fillColor: fillColor);

  await _tapIconButtonBySvgKey(tester, 'app_icon_circle');
  await tester.pump();

  final TestGesture gesture = await tester.startGesture(
    center - Offset(radius / AppMath.pair, 0),
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );

  await gesture.moveTo(center + Offset(radius / AppMath.pair, 0));
  await gesture.up();
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Flood fill
// ---------------------------------------------------------------------------

/// Performs a solid flood fill at [position] with [color].
///
/// Selects the fill tool and solid mode via UI taps, then executes the fill
/// inside [WidgetTester.runAsync] because the pixel-level flood fill requires
/// real async I/O (`image.toByteData`) that cannot complete in the fake async
/// zone of widget tests.
Future<void> performFloodFillSolid(
  final WidgetTester tester, {
  required final Offset position,
  required final Color color,
  int? tolerance,
}) async {
  // Select fill tool and solid mode via UI
  await tapByKey(tester, Keys.toolFill);
  await tapByKey(tester, Keys.toolFillModeSolid);

  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  appProvider.fillColor = color;
  if (tolerance != null) {
    appProvider.tolerance = tolerance;
  }

  // Record tap at fill position for video overlay
  InteractionTracker.recordTap(position);

  final Offset canvasPosition = appProvider.toCanvas(position);
  await tester.runAsync(() async {
    final ui.Image sourceImage = appProvider.layers.selectedLayer.toImageForStorage(appProvider.layers.size);
    final FillService fillService = FillService();
    final UserActionDrawing action = await fillService.createFloodFillSolidAction(
      sourceImage: sourceImage,
      position: canvasPosition,
      fillColor: color,
      tolerance: tolerance ?? appProvider.tolerance,
      clipPath: null,
    );
    sourceImage.dispose();

    final ui.Rect bounds = action.path?.getBounds() ?? ui.Rect.zero;
    debugPrint(
      '🎨 Solid fill at canvas(${canvasPosition.dx.toInt()}, ${canvasPosition.dy.toInt()}) '
      '→ region ${bounds.width.toInt()}x${bounds.height.toInt()}',
    );

    appProvider.recordExecuteDrawingActionToSelectedLayer(action: action);
  });

  await UnitTestVideoRecorder.captureAfterInteraction(tester);
}

/// Performs a solid flood fill at the given [canvasPosition] (in canvas pixel
/// coordinates, not screen coordinates).
///
/// Selects the fill tool and solid mode via UI taps, then executes the fill
/// inside [WidgetTester.runAsync].
///
/// Use this instead of [performFloodFillSolid] when screen-to-canvas conversion
/// via [AppProvider.toCanvas] is unreliable (e.g. after zoom-out).
Future<void> performFloodFillSolidAtCanvasPosition(
  final WidgetTester tester, {
  required final Offset canvasPosition,
  required final Color color,
  int? tolerance,
}) async {
  // Select fill tool and solid mode via UI
  await tapByKey(tester, Keys.toolFill);
  await tapByKey(tester, Keys.toolFillModeSolid);

  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  appProvider.fillColor = color;
  if (tolerance != null) {
    appProvider.tolerance = tolerance;
  }

  // Record tap at approximate screen position for video overlay
  final Offset screenPos = appProvider.fromCanvas(canvasPosition);
  InteractionTracker.recordTap(screenPos);

  await tester.runAsync(() async {
    final ui.Image sourceImage = appProvider.layers.selectedLayer.toImageForStorage(appProvider.layers.size);
    final FillService fillService = FillService();
    final UserActionDrawing action = await fillService.createFloodFillSolidAction(
      sourceImage: sourceImage,
      position: canvasPosition,
      fillColor: color,
      tolerance: tolerance ?? appProvider.tolerance,
      clipPath: null,
    );
    sourceImage.dispose();

    final ui.Rect bounds = action.path?.getBounds() ?? ui.Rect.zero;
    debugPrint(
      '🎨 Solid fill at canvas(${canvasPosition.dx.toInt()}, ${canvasPosition.dy.toInt()}) '
      '→ region ${bounds.width.toInt()}x${bounds.height.toInt()}',
    );

    appProvider.recordExecuteDrawingActionToSelectedLayer(action: action);
  });

  await UnitTestVideoRecorder.captureAfterInteraction(tester);
}

/// Performs a gradient flood fill with the specified [gradientMode] and [gradientPoints].
///
/// Selects the fill tool and gradient mode via UI taps, then executes the fill
/// inside [WidgetTester.runAsync] for the same reason as [performFloodFillSolid].
Future<void> performFloodFillGradient(
  final WidgetTester tester, {
  required final FillMode gradientMode,
  required final List<GradientPoint> gradientPoints,
  Offset Function(Offset)? toCanvas,
}) async {
  // Select fill tool and gradient mode via UI
  await tapByKey(tester, Keys.toolFill);
  final Key modeKey = gradientMode == FillMode.linear ? Keys.toolFillModeLinear : Keys.toolFillModeRadial;
  await tapByKey(tester, modeKey);

  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Record tap at first gradient point for video overlay
  if (gradientPoints.isNotEmpty) {
    InteractionTracker.recordTap(gradientPoints.first.offset);
  }

  final FillModel fillModel = FillModel();
  fillModel.mode = gradientMode;
  for (final GradientPoint point in gradientPoints) {
    fillModel.gradientPoints.add(
      GradientPoint(offset: point.offset, color: point.color),
    );
  }

  final ui.Image sourceImage = appProvider.layers.selectedLayer.toImageForStorage(appProvider.layers.size);

  await tester.runAsync(() async {
    final FillService fillService = FillService();
    final UserActionDrawing action = await fillService.createFloodFillGradientAction(
      sourceImage: sourceImage,
      fillModel: fillModel,
      tolerance: appProvider.tolerance,
      clipPath: null,
      toCanvas: toCanvas ?? appProvider.toCanvas,
    );
    appProvider.recordExecuteDrawingActionToSelectedLayer(action: action);
  });

  await UnitTestVideoRecorder.captureAfterInteraction(tester);
}

// ---------------------------------------------------------------------------
// Layer management
// ---------------------------------------------------------------------------

/// Helpers for managing layers during painting tests.
class PaintingLayerHelpers {
  /// Adds a new layer above the current selection via UI and renames it.
  ///
  /// Taps the "Add a layer above" button in the layer panel, then opens the
  /// rename dialog via long-press on the new layer's name and enters [name].
  static Future<void> addNewLayer(
    final WidgetTester tester,
    final String name,
  ) async {
    // Tap the "Add a layer above" button visible on the selected layer.
    await tapByTooltip(tester, _uiTooltipAddLayerAbove);
    await tester.pumpAndSettle();

    // Determine the default name assigned to the newly created layer.
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    final String defaultName = layersProvider.selectedLayer.name;

    // Long-press on the layer name text to open the rename dialog.
    final Finder layerNameText = find.text(defaultName);
    expect(layerNameText, findsWidgets, reason: 'Should find the new layer name "$defaultName"');
    await tester.longPress(layerNameText.first);
    await tester.pumpAndSettle();

    // Enter the desired name in the rename dialog's TextField.
    final Finder dialogFinder = find.byType(AlertDialog);
    expect(dialogFinder, findsOneWidget, reason: 'Layer rename dialog should be visible');
    final Finder textField = find.descendant(
      of: dialogFinder,
      matching: find.byType(TextField),
    );
    await tester.enterText(textField.first, name);

    // Tap "Apply" to confirm the rename.
    final Finder applyButton = find.descendant(
      of: dialogFinder,
      matching: find.text(_uiDialogApply),
    );
    await tester.tap(applyButton);
    await tester.pumpAndSettle();
  }

  /// Switches to the layer at [layerIndex].
  static Future<void> switchToLayer(
    final WidgetTester tester,
    final int layerIndex,
  ) async {
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    layersProvider.selectedLayerIndex = layerIndex;
    await tester.pump();
  }

  /// Switches to the first layer matching [layerName].
  static Future<void> switchToLayerByName(
    final WidgetTester tester,
    final String layerName,
  ) async {
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);

    for (int i = 0; i < layersProvider.length; i++) {
      if (layersProvider.get(i).name == layerName) {
        layersProvider.selectedLayerIndex = i;
        await tester.pump();
        return;
      }
    }
    fail('Layer "$layerName" not found');
  }

  /// Merges layer at [fromIndex] into the layer below it.
  static Future<void> mergeLayer(
    final WidgetTester tester,
    final int fromIndex,
    final int toIndex,
  ) async {
    await switchToLayer(tester, fromIndex);
    await _tapIconButtonBySvgKey(tester, 'app_icon_layers');
    await tester.pump();
  }

  /// Removes the layer at [layerIndex].
  static Future<void> removeLayer(
    final WidgetTester tester,
    final int layerIndex,
  ) async {
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    final LayerProvider layer = layersProvider.get(layerIndex);
    layersProvider.remove(layer);
    layersProvider.update();
    await tester.pump();
  }

  /// Renames the currently selected layer.
  static Future<void> renameLayer(
    final WidgetTester tester,
    final String newName,
  ) async {
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    layersProvider.selectedLayer.name = newName;
    layersProvider.update();
    await tester.pump();
  }

  /// Prints the current layer structure for debugging.
  static Future<void> printLayerStructure(final WidgetTester tester) async {
    await tester.pump();
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    debugPrint('📚 Layer Structure:');
    for (int i = 0; i < layersProvider.length; i++) {
      final LayerProvider layer = layersProvider.get(i);
      final String selected = layer.isSelected ? ' ← SELECTED' : '';
      final String visible = layer.isVisible ? '👁️' : '👁️‍🗨️';
      debugPrint('  [$i] $visible "${layer.name}" - ${layer.actionStack.length} actions$selected');
    }
  }
}

// ---------------------------------------------------------------------------
// Text placement via UI
// ---------------------------------------------------------------------------

/// Places a text object on the canvas by selecting the text tool, tapping
/// on the canvas, and interacting with the text editor dialog.
///
/// Sets [fontSize] and [color] on [AppProvider] before tapping so the dialog
/// opens with the correct initial values.  The font size slider and color
/// picker dialog are not manipulated directly because their continuous
/// nature makes exact values fragile in widget tests.
Future<void> placeTextViaUI(
  final WidgetTester tester, {
  required final Offset canvasPosition,
  required final String text,
  required final double fontSize,
  required final Color color,
  final FontWeight fontWeight = FontWeight.normal,
  final String? fontFamily,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Pre-configure the text tool settings so the dialog opens with the
  // desired initial font size and color.
  appProvider.brushSize = fontSize;
  appProvider.brushColor = color;

  // Select the text tool via UI.
  await _tapIconButtonBySvgKey(tester, '${appIconKeyPrefix}fontDownload');
  await tester.pump();

  // Tap on the canvas at the target position to open the text dialog.
  final Offset screenPosition = appProvider.fromCanvas(canvasPosition);
  await tapLikeHuman(tester, screenPosition);
  await tester.pumpAndSettle();

  // Interact with the TextEditorDialog.
  final Finder dialogFinder = find.byType(AlertDialog);
  expect(dialogFinder, findsOneWidget, reason: 'Text editor dialog should be visible');

  // Enter text into the text field.
  final Finder textField = find.descendant(
    of: dialogFinder,
    matching: find.byType(TextField),
  );
  await tester.enterText(textField.first, text);
  await tester.pump();

  // Toggle bold if requested.
  if (fontWeight == FontWeight.bold) {
    final Finder boldIcon = find.descendant(
      of: dialogFinder,
      matching: find.byKey(const ValueKey<String>('${appIconKeyPrefix}formatBold')),
    );
    final Finder boldButton = find.ancestor(
      of: boldIcon,
      matching: find.byType(IconButton),
    );
    await tester.tap(boldButton.first);
    await tester.pump();
  }

  // Tap the "Add Text" action button (find the TextButton, not the title).
  final Finder addTextButton = find.descendant(
    of: dialogFinder,
    matching: find.widgetWithText(TextButton, 'Add Text'),
  );
  await tester.tap(addTextButton.first);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Canvas resize via UI
// ---------------------------------------------------------------------------

/// Resizes the canvas by opening the canvas settings dialog from the main
/// menu, entering the new dimensions, selecting the anchor position, and
/// tapping Apply.
Future<void> resizeCanvasViaUI(
  final WidgetTester tester, {
  required final int width,
  required final int height,
  required final CanvasResizePosition position,
}) async {
  // Open the main menu.
  await tapByTooltip(tester, _uiMenuTooltip);
  await tester.pumpAndSettle();

  // Tap "Canvas..." menu item.
  final Finder canvasMenuItem = find.text(_uiMenuCanvasSettings);
  expect(canvasMenuItem, findsOneWidget, reason: 'Should find Canvas... menu item');
  await tester.tap(canvasMenuItem);
  await tester.pumpAndSettle();

  // The canvas settings bottom sheet is now visible.

  // Unlock aspect ratio if locked (default is locked) by tapping the link icon.
  final Finder linkIcon = find.byKey(const ValueKey<String>('${appIconKeyPrefix}link'));
  if (linkIcon.evaluate().isNotEmpty) {
    final Finder lockButton = find.ancestor(
      of: linkIcon,
      matching: find.byType(IconButton),
    );
    if (lockButton.evaluate().isNotEmpty) {
      await tester.tap(lockButton.first);
      await tester.pumpAndSettle();
    }
  }

  // Find the width and height TextFields by their label text.
  final Finder widthField = find.widgetWithText(TextField, 'Width');
  final Finder heightField = find.widgetWithText(TextField, 'Height');

  // Enter new width.
  await tester.enterText(widthField.first, width.toString());
  await tester.pump();

  // Enter new height.
  await tester.enterText(heightField.first, height.toString());
  await tester.pump();

  // Select the anchor position in the NineGridSelector.
  // The positions map to enum indices 0..8 in the grid.
  final Finder gridSelector = find.byType(NineGridSelector);
  expect(gridSelector, findsOneWidget, reason: 'NineGridSelector should be visible');

  // Find the GestureDetector at the desired index within the grid.
  final Finder gridGestureDetectors = find.descendant(
    of: gridSelector,
    matching: find.byType(GestureDetector),
  );
  await tester.tap(gridGestureDetectors.at(position.index));
  await tester.pump();

  // Tap "Apply" to execute the resize.
  final Finder applyButton = find.text(_uiDialogApply);
  await tester.tap(applyButton.first);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Screenshot capture
// ---------------------------------------------------------------------------

/// Captures the app screenshot boundary and saves it to a file.
///
/// Uses [WidgetTester.runAsync] to escape the fake async zone, which is
/// required for [RenderRepaintBoundary.toImage] to complete in widget tests.
Future<void> saveUnitTestScreenshot(
  final WidgetTester tester, {
  required final String filename,
}) async {
  await tester.pump();

  final Finder boundaryFinder = find.byKey(Keys.appScreenshotBoundary);
  expect(
    boundaryFinder,
    findsOneWidget,
    reason: 'Expected the app screenshot boundary to be present',
  );

  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
    final ui.Image image = await boundary.toImage(
      pixelRatio: AppDefaults.renderedScreenshotPixelRatio,
    );
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Failed to encode unit test screenshot');
    }

    final Directory outputDir = Directory('$_unitTestOutputDirectoryPath/$_unitTestScreenshotDirectoryName');
    await outputDir.create(recursive: true);
    final File outputFile = File('${outputDir.path}/$filename');
    await outputFile.writeAsBytes(byteData.buffer.asUint8List());
    debugPrint('📸 Unit test screenshot saved: ${outputFile.path}');
  });
}

/// Captures the layered artwork and saves it as a JPG file.
///
/// Uses [WidgetTester.runAsync] for the same reason as [saveUnitTestScreenshot].
Future<void> saveUnitTestArtworkScreenshot(
  final WidgetTester tester, {
  required final String filename,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);

  await tester.runAsync(() async {
    final Uint8List artworkBytes = await layersProvider.capturePainterToImageBytes();
    final img.Image? decoded = img.decodeImage(artworkBytes);
    if (decoded == null) {
      throw StateError('Failed to decode artwork image bytes');
    }

    final Uint8List jpgBytes = Uint8List.fromList(
      img.encodeJpg(decoded, quality: AppDefaults.integrationEvidenceJpegQuality),
    );

    final Directory outputDir = Directory('$_unitTestOutputDirectoryPath/$_unitTestScreenshotDirectoryName');
    await outputDir.create(recursive: true);
    final File outputFile = File('${outputDir.path}/$filename');
    await outputFile.writeAsBytes(jpgBytes);
    debugPrint('📸 Unit test artwork saved: ${outputFile.path}');
  });
}

/// Saves the current layered artwork as an ORA archive to the test output directory.
///
/// Uses [WidgetTester.runAsync] for the same reason as [saveUnitTestScreenshot].
Future<void> saveUnitTestOraArchive(
  final WidgetTester tester, {
  required final String filename,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);

  await tester.runAsync(() async {
    final List<int> bytes = await createOraAchive(layersProvider);

    final Directory outputDir = Directory(_unitTestOutputDirectoryPath);
    await outputDir.create(recursive: true);
    final File outputFile = File('${outputDir.path}/$filename');
    await outputFile.writeAsBytes(bytes);
    debugPrint('📦 Unit test ORA archive saved: ${outputFile.path}');
  });
}

/// Saves the current artwork as a flattened PNG to the test output directory.
Future<void> saveUnitTestPng(
  final WidgetTester tester, {
  required final String filename,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);

  await tester.runAsync(() async {
    final Uint8List bytes = await layersProvider.capturePainterToImageBytes();
    final Directory outputDir = Directory(_unitTestOutputDirectoryPath);
    await outputDir.create(recursive: true);
    final File outputFile = File('${outputDir.path}/$filename');
    await outputFile.writeAsBytes(bytes);
    debugPrint('📦 Unit test PNG saved: ${outputFile.path}');
  });
}

/// Saves the current artwork as a JPEG to the test output directory.
Future<void> saveUnitTestJpeg(
  final WidgetTester tester, {
  required final String filename,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);

  await tester.runAsync(() async {
    final Uint8List pngBytes = await layersProvider.capturePainterToImageBytes();
    final Uint8List jpgBytes = await convertToJpg(pngBytes);
    final Directory outputDir = Directory(_unitTestOutputDirectoryPath);
    await outputDir.create(recursive: true);
    final File outputFile = File('${outputDir.path}/$filename');
    await outputFile.writeAsBytes(jpgBytes);
    debugPrint('📦 Unit test JPEG saved: ${outputFile.path}');
  });
}

/// Saves all layers as a layered TIFF to the test output directory.
Future<void> saveUnitTestTiff(
  final WidgetTester tester, {
  required final String filename,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);

  await tester.runAsync(() async {
    final String normalizedFileName = normalizeTiffExportFileName(filename);
    final Uint8List tiffBytes = await convertLayersToTiff(layersProvider);
    final Directory outputDir = Directory(_unitTestOutputDirectoryPath);
    await outputDir.create(recursive: true);
    final File outputFile = File('${outputDir.path}/$normalizedFileName');
    await outputFile.writeAsBytes(tiffBytes);
    debugPrint('📦 Unit test TIFF saved: ${outputFile.path}');
  });
}

/// Saves the current artwork as a WebP to the test output directory.
Future<void> saveUnitTestWebp(
  final WidgetTester tester, {
  required final String filename,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);

  await tester.runAsync(() async {
    final ui.Image image = await layersProvider.capturePainterToImage();
    final Uint8List webpBytes = await convertImageToWebp(image);
    final Directory outputDir = Directory(_unitTestOutputDirectoryPath);
    await outputDir.create(recursive: true);
    final File outputFile = File('${outputDir.path}/$filename');
    await outputFile.writeAsBytes(webpBytes);
    debugPrint('📦 Unit test WebP saved: ${outputFile.path}');
  });
}

// ---------------------------------------------------------------------------
// Interaction overlay rendering
// ---------------------------------------------------------------------------

/// Composites interaction overlays onto a base screenshot image.
///
/// Returns a new [ui.Image] with tap targets and drag indicators drawn on
/// top.  The caller is responsible for disposing the returned image.  The
/// original [base] image is **not** disposed by this function.
ui.Image _compositeOverlays(
  ui.Image base,
  List<InteractionRecord> interactions,
) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  // Draw the base screenshot.
  canvas.drawImage(base, Offset.zero, Paint());

  // Draw each recorded interaction on top.
  for (final InteractionRecord record in interactions) {
    switch (record.type) {
      case InteractionType.tap:
        _drawTapIndicator(canvas, record.position);
      case InteractionType.drag:
        _drawDragIndicator(canvas, record.position, record.endPosition!);
    }
  }

  final ui.Picture picture = recorder.endRecording();
  final ui.Image result = picture.toImageSync(base.width, base.height);
  picture.dispose();
  return result;
}

/// Draws a red crosshair-and-circle tap indicator at [center].
void _drawTapIndicator(Canvas canvas, Offset center) {
  final Paint outlinePaint = Paint()
    ..color = _indicatorOutlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = _indicatorOutlineWidth
    ..strokeCap = StrokeCap.round;

  final Paint strokePaint = Paint()
    ..color = _tapIndicatorColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = _tapIndicatorStrokeWidth
    ..strokeCap = StrokeCap.round;

  final Paint fillPaint = Paint()
    ..color = _tapIndicatorColor
    ..style = PaintingStyle.fill;

  // Circle — outline for contrast, then red stroke.
  canvas.drawCircle(center, _tapIndicatorRadius, outlinePaint);
  canvas.drawCircle(center, _tapIndicatorRadius, strokePaint);

  // Horizontal crosshair.
  final Offset hStart = center - const Offset(_tapCrosshairLength, 0);
  final Offset hEnd = center + const Offset(_tapCrosshairLength, 0);
  canvas.drawLine(hStart, hEnd, outlinePaint);
  canvas.drawLine(hStart, hEnd, strokePaint);

  // Vertical crosshair.
  final Offset vStart = center - const Offset(0, _tapCrosshairLength);
  final Offset vEnd = center + const Offset(0, _tapCrosshairLength);
  canvas.drawLine(vStart, vEnd, outlinePaint);
  canvas.drawLine(vStart, vEnd, strokePaint);

  // Inner dot.
  canvas.drawCircle(center, _tapDotRadius, fillPaint);
}

/// Draws a blue line-with-arrowhead drag indicator from [start] to [end].
void _drawDragIndicator(Canvas canvas, Offset start, Offset end) {
  final Paint outlinePaint = Paint()
    ..color = _indicatorOutlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = _indicatorOutlineWidth
    ..strokeCap = StrokeCap.round;

  final Paint strokePaint = Paint()
    ..color = _dragIndicatorColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = _dragIndicatorStrokeWidth
    ..strokeCap = StrokeCap.round;

  final Paint fillPaint = Paint()
    ..color = _dragIndicatorColor
    ..style = PaintingStyle.fill;

  // Line from start to end.
  canvas.drawLine(start, end, outlinePaint);
  canvas.drawLine(start, end, strokePaint);

  // Start circle.
  canvas.drawCircle(start, _dragStartCircleRadius, outlinePaint);
  canvas.drawCircle(start, _dragStartCircleRadius, strokePaint);

  // Arrowhead at end.
  final double angle = (end - start).direction;
  final Offset arrow1 =
      end -
      Offset(
        _dragArrowHeadLength * math.cos(angle - _dragArrowHeadAngle),
        _dragArrowHeadLength * math.sin(angle - _dragArrowHeadAngle),
      );
  final Offset arrow2 =
      end -
      Offset(
        _dragArrowHeadLength * math.cos(angle + _dragArrowHeadAngle),
        _dragArrowHeadLength * math.sin(angle + _dragArrowHeadAngle),
      );
  final Path arrowPath = Path()
    ..moveTo(end.dx, end.dy)
    ..lineTo(arrow1.dx, arrow1.dy)
    ..lineTo(arrow2.dx, arrow2.dy)
    ..close();

  canvas.drawPath(arrowPath, outlinePaint);
  canvas.drawPath(arrowPath, fillPaint);
}

// ---------------------------------------------------------------------------
// Video recording
// ---------------------------------------------------------------------------

/// Records numbered PNG frames at each test checkpoint and assembles them
/// into an MP4 video using ffmpeg when [stop] is called.
///
/// When active, tap helpers automatically capture a frame with the red
/// target overlay drawn at the tap position.
///
/// All frame capture uses [WidgetTester.runAsync] so that
/// [RenderRepaintBoundary.toImage] completes in the fake async zone.
class UnitTestVideoRecorder {
  UnitTestVideoRecorder(this._tester);

  final WidgetTester _tester;
  int _frameIndex = 0;
  int _frameErrors = 0;
  late final Directory _framesDirectory;

  /// The currently active recorder, if any.
  ///
  /// Tap helpers check this to auto-capture a frame after each interaction.
  static UnitTestVideoRecorder? _active;

  /// Captures a frame with interaction overlays if a recorder is active.
  ///
  /// Called automatically by tap helpers; does nothing when no recording is
  /// in progress.
  static Future<void> captureAfterInteraction(WidgetTester tester) async {
    if (_active != null) {
      await _active!.captureFrame();
    }
  }

  /// Initialize the frames directory, clearing any previous frames.
  Future<void> start() async {
    _framesDirectory = Directory(
      '$_unitTestOutputDirectoryPath/$_unitTestScreenshotDirectoryName/$_videoFrameSubdirectoryName',
    );

    await _tester.runAsync(() async {
      await _framesDirectory.create(recursive: true);

      await for (final FileSystemEntity entity in _framesDirectory.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    });

    _frameIndex = 0;
    _frameErrors = 0;
    _active = this;
    debugPrint('🎬 Video recorder started — frames: ${_framesDirectory.path}');
  }

  /// Captures the current app screenshot boundary as a numbered PNG frame.
  ///
  /// Any pending [InteractionTracker] records are composited as overlays
  /// (red tap targets, blue drag arrows) before saving.
  Future<void> captureFrame() async {
    await _tester.pumpAndSettle();

    final Finder boundaryFinder = find.byKey(Keys.appScreenshotBoundary);
    if (boundaryFinder.evaluate().isEmpty) {
      _frameErrors++;
      return;
    }

    // Snapshot and clear pending interactions before entering runAsync.
    final List<InteractionRecord> pendingInteractions = InteractionTracker.records.toList();
    InteractionTracker.clear();

    await _tester.runAsync(() async {
      try {
        final RenderRepaintBoundary boundary = _tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
        ui.Image image = await boundary.toImage(
          pixelRatio: AppDefaults.renderedScreenshotPixelRatio,
        );

        // Composite interaction overlays onto the frame if any are pending.
        if (pendingInteractions.isNotEmpty) {
          final ui.Image composited = _compositeOverlays(image, pendingInteractions);
          image.dispose();
          image = composited;
        }

        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();

        if (byteData == null) {
          _frameErrors++;
          return;
        }

        final String paddedIndex = _frameIndex.toString().padLeft(_videoFrameIndexPadding, '0');
        final File frameFile = File(
          '${_framesDirectory.path}/$_videoFrameFilenamePrefix$paddedIndex.$_videoFrameFileExtension',
        );
        await frameFile.writeAsBytes(
          byteData.buffer.asUint8List(),
          flush: true,
        );
        _frameIndex++;
      } catch (e) {
        _frameErrors++;
        debugPrint('🎬 Frame capture failed: $e');
      }
    });
  }

  /// Stops recording, assembles the frames into an MP4 using ffmpeg,
  /// and cleans up the frames directory on success.
  Future<void> stop() async {
    await captureFrame();
    _active = null;

    debugPrint(
      '🎬 Video recorder stopped: $_frameIndex frames, $_frameErrors errors',
    );

    if (_frameIndex == 0) {
      debugPrint('🎬 No frames to assemble');
      return;
    }

    await _tester.runAsync(() async {
      final ProcessResult whichResult = await Process.run('which', <String>['ffmpeg']);
      if (whichResult.exitCode != 0) {
        debugPrint(
          '⚠️ ffmpeg not found — frames saved in: ${_framesDirectory.path}',
        );
        return;
      }

      final Directory outputDir = Directory(_unitTestOutputDirectoryPath);
      await outputDir.create(recursive: true);
      final String outputPath = '${outputDir.path}/$_videoOutputFilename';

      final ProcessResult result = await Process.run(
        'ffmpeg',
        <String>[
          '-y',
          '-framerate',
          '$_videoFramesFps',
          '-i',
          '${_framesDirectory.path}/$_videoFrameFilenamePrefix%0${_videoFrameIndexPadding}d.$_videoFrameFileExtension',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          outputPath,
        ],
      );

      if (result.exitCode == 0) {
        debugPrint('🎬 Video assembled: $outputPath ($_frameIndex frames)');
        await _framesDirectory.delete(recursive: true);
      } else {
        debugPrint('⚠️ ffmpeg failed — frames preserved in: ${_framesDirectory.path}');
        debugPrint('ffmpeg stderr: ${result.stderr}');
      }
    });
  }
}
