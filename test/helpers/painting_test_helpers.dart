// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
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
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/fill_service.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:fpaint/widgets/nine_grid_selector.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';
import 'package:image/image.dart' as img;

/// Number of incremental steps used in human-like drag gestures.
const double _humanDragSteps = 3;

/// Minimum number of vertices required to form a lasso selection polygon.
const int _lassoSelectionMinimumPointCount = 3;

/// Tooltip label for selector math: replace current selection.
const String _selectorMathReplaceTooltip = 'Replace';

/// Tooltip label for selector math: add to current selection.
const String _selectorMathAddTooltip = 'Add';

/// Tooltip label for selector math: remove from current selection.
const String _selectorMathRemoveTooltip = 'Remove';

/// Tooltip label for selector operation: invert current selection.
const String _selectorInvertTooltip = 'Invert';

/// Minimum number of points required to draw a freehand stroke.
const int _freehandStrokeMinimumPointCount = 2;

/// Total number of deform handles shown by the transform overlay.
const int _transformOverlayHandleCount = 9;

/// Build-order index for the transform overlay's top-left corner handle.
const int _transformOverlayHandleTopLeftIndex = 0;

/// Build-order index for the transform overlay's top-right corner handle.
const int _transformOverlayHandleTopRightIndex = 1;

/// Build-order index for the transform overlay's bottom-right corner handle.
const int _transformOverlayHandleBottomRightIndex = 2;

/// Build-order index for the transform overlay's bottom-left corner handle.
const int _transformOverlayHandleBottomLeftIndex = 3;

/// Build-order index for the transform overlay's top edge handle.
const int _transformOverlayHandleTopIndex = 4;

/// Build-order index for the transform overlay's right edge handle.
const int _transformOverlayHandleRightIndex = 5;

/// Build-order index for the transform overlay's bottom edge handle.
const int _transformOverlayHandleBottomIndex = 6;

/// Build-order index for the transform overlay's left edge handle.
const int _transformOverlayHandleLeftIndex = 7;

/// Build-order index for the transform overlay's center move handle.
const int _transformOverlayHandleCenterIndex = 8;

/// Device pixel ratio used for unit test screenshots.
const double _unitTestDevicePixelRatio = 1.0;

/// Base output directory for generated unit test artifacts.
const String _unitTestOutputDirectoryPath = 'test/output';

bool _unitTestExportSheetIsOpen = false;

/// Number of fixed transition pumps used by the export UI helper.
const int _unitTestExportUiTransitionPumpCount = 4;

/// Duration of each fixed transition pump used by the export UI helper.
const Duration _unitTestExportUiTransitionPumpDuration = Duration(milliseconds: 50);

/// Maximum number of settle pumps performed before test interactions continue.
const int _unitTestUiSettlePumpCount = 12;

/// Duration of each bounded settle pump before test interactions continue.
const Duration _unitTestUiSettlePumpDuration = Duration(milliseconds: 16);

/// Share-sheet label for PNG export actions.
const String _unitTestPngShareActionFileName = 'image.PNG';

/// Share-sheet label for JPEG export actions.
const String _unitTestJpegShareActionFileName = 'image.JPG';

/// Share-sheet label for ORA export actions.
const String _unitTestOraShareActionFileName = 'image.ORA';

/// Share-sheet label for TIFF export actions.
const String _unitTestTiffShareActionFileName = 'image.TIF';

/// Share-sheet label for WebP export actions.
const String _unitTestWebpShareActionFileName = 'image.WEBP';

/// File-picker suggestion used by PNG exports.
const String _unitTestPngPickerFileName = 'image.png';

/// File-picker suggestion used by JPEG exports.
const String _unitTestJpegPickerFileName = 'image.jpg';

/// File-picker suggestion used by ORA exports.
const String _unitTestOraPickerFileName = 'image.ora';

/// File-picker suggestion used by TIFF exports.
const String _unitTestTiffPickerFileName = 'image.tif';

/// File-picker suggestion used by WebP exports.
const String _unitTestWebpPickerFileName = 'image.webp';

/// Save-dialog extension filters used by PNG exports.
const List<String> _unitTestPngAllowedExtensions = <String>[FileExtensions.png];

/// Save-dialog extension filters used by JPEG exports.
const List<String> _unitTestJpegAllowedExtensions = <String>[
  FileExtensions.jpg,
  FileExtensions.jpeg,
];

/// Save-dialog extension filters used by ORA exports.
const List<String> _unitTestOraAllowedExtensions = <String>[FileExtensions.ora];

/// Save-dialog extension filters used by TIFF exports.
const List<String> _unitTestTiffAllowedExtensions = <String>[FileExtensions.tif];

/// Save-dialog extension filters used by WebP exports.
const List<String> _unitTestWebpAllowedExtensions = <String>[FileExtensions.webp];

/// Subdirectory for unit test screenshot output within [_unitTestOutputDirectoryPath].
const String _unitTestScreenshotDirectoryName = 'screenshots';

/// Prefix used for the temporary directory that stages video frames.
const String _videoFrameTemporaryDirectoryPrefix = 'fpaint_unit_test_video_frames_';

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

/// Fixed creation-time metadata embedded in the MP4 container so the output
/// is byte-identical across test runs.
const String _ffmpegFixedCreationTime = '2000-01-01T00:00:00';

/// Thread count for ffmpeg encoding.  Single-threaded ensures deterministic
/// output so that two identical test runs produce byte-identical MP4 files.
const int _ffmpegThreadCount = 1;

/// Width of the deterministic frame signature embedded into the MP4 metadata.
const int _videoFrameSignatureHexLength = 16;

/// Bit width of the deterministic frame signature.
const int _videoFrameSignatureBitWidth = 64;

/// Radix used to encode the deterministic frame signature as lowercase hex.
const int _videoFrameSignatureRadix = 16;

/// Initial FNV-1a hash basis for frame-signature calculation.
const int _fnv1a64OffsetBasis = 0xCBF29CE484222325;

/// FNV-1a prime for frame-signature calculation.
const int _fnv1a64Prime = 0x100000001B3;

/// Mask used to keep the frame-signature hash in 64 bits.
const int _fnv1a64Mask = 0xFFFFFFFFFFFFFFFF;

/// Executable name used to locate ffmpeg on the host.
const String _whichExecutableName = 'which';

/// Executable name used to assemble the MP4 artifact.
const String _ffmpegExecutableName = 'ffmpeg';

/// ffmpeg flag used to overwrite the temporary output file.
const String _ffmpegOverwriteOutputFlag = '-y';

/// ffmpeg flag used to request bit-exact muxing.
const String _ffmpegBitExactFlag = '-fflags';

/// ffmpeg value used to request bit-exact muxing and encoding.
const String _ffmpegBitExactValue = '+bitexact';

/// ffmpeg flag used to set the input frame rate.
const String _ffmpegFrameRateFlag = '-framerate';

/// ffmpeg flag used to provide the image-sequence input pattern.
const String _ffmpegInputFlag = '-i';

/// ffmpeg flag used to drop input metadata.
const String _ffmpegStripMetadataFlag = '-map_metadata';

/// ffmpeg flag used to drop input chapters.
const String _ffmpegStripChaptersFlag = '-map_chapters';

/// ffmpeg value used to disable metadata and chapter mapping.
const String _ffmpegDisableSourceMappingValue = '-1';

/// ffmpeg flag used to select the video codec.
const String _ffmpegCodecFlag = '-c:v';

/// ffmpeg codec used for the committed unit-test video artifact.
const String _ffmpegCodecValue = 'libx264';

/// ffmpeg flag used to request bit-exact video encoding.
const String _ffmpegVideoFlagsFlag = '-flags:v';

/// ffmpeg flag used to configure encoder thread count.
const String _ffmpegThreadCountFlag = '-threads';

/// ffmpeg flag used to force a stable pixel format.
const String _ffmpegPixelFormatFlag = '-pix_fmt';

/// Pixel format used for the committed unit-test video artifact.
const String _ffmpegPixelFormatValue = 'yuv420p';

/// ffmpeg flag used to set explicit output metadata values.
const String _ffmpegMetadataFlag = '-metadata';

/// Fixed creation-time metadata passed to ffmpeg.
const String _ffmpegCreationTimeMetadataValue = 'creation_time=$_ffmpegFixedCreationTime';

/// Metadata key used to embed the deterministic frame signature into the MP4.
const String _videoFrameSignatureMetadataKey = 'comment';

/// Prefix used to locate the embedded deterministic frame signature in the MP4.
const String _videoFrameSignatureMetadataPrefix = 'frame_signature:';

/// Suffix used for temporary output files before a successful rename.
const String _temporaryVideoOutputSuffix = 'tmp';

/// Debug message prefix emitted when no visual change was detected.
const String _videoFrameSignatureKeepExistingMessagePrefix = '🎬 Video frames unchanged, keeping ';

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

/// Primary color of tap indicators (red with some transparency).
const Color _tapIndicatorColor = Color.fromARGB(200, 255, 50, 50);

/// Primary color of drag indicators (blue with some transparency).
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

/// Simulates a tap at [position] but avoids waiting for all animations or
/// async work to settle before recording the post-tap frame.
///
/// This is useful for actions that intentionally kick off longer-running work,
/// such as export flows, where an immediate `pumpAndSettle` can hang the test.
Future<void> tapLikeHumanWithoutSettling(
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
  await tester.pump();
  await UnitTestVideoRecorder.captureAfterInteraction(tester, settle: false);
}

Future<void> pressListTileWithoutSettling(
  final WidgetTester tester,
  final Finder target,
) async {
  expect(target, findsOneWidget, reason: 'Should find exactly one visible list tile');

  final ListTile tile = tester.widget<ListTile>(target.first);
  final GestureTapCallback? onTap = tile.onTap;
  expect(onTap, isNotNull, reason: 'Expected list tile to be tappable');

  InteractionTracker.recordTap(tester.getCenter(target.first));
  final dynamic tapResult = (onTap! as dynamic)();
  if (tapResult is Future<void>) {
    await tapResult;
  }
  await tester.pump();
  await UnitTestVideoRecorder.captureAfterInteraction(tester, settle: false);
}

Future<void> openPopupMenuButtonWithoutSettling<T>(
  final WidgetTester tester,
  final Finder target,
) async {
  expect(target, findsOneWidget, reason: 'Should find exactly one visible popup menu button');

  InteractionTracker.recordTap(tester.getCenter(target.first));
  final PopupMenuButtonState<T> state = tester.state<PopupMenuButtonState<T>>(target);
  state.showButtonMenu();
  await tester.pump();
  await UnitTestVideoRecorder.captureAfterInteraction(tester, settle: false);
}

Future<void> tapFinderWithoutSettling(
  final WidgetTester tester,
  final Finder target,
) async {
  expect(target, findsOneWidget, reason: 'Should find exactly one visible tappable widget');

  await tester.ensureVisible(target.first);
  await tester.pump();

  final Finder tappable = target.hitTestable();
  expect(tappable, findsOneWidget, reason: 'Should find exactly one hit-testable widget');

  InteractionTracker.recordTap(tester.getCenter(tappable.first));
  await tester.tap(tappable.first);
  await tester.pump();
  await UnitTestVideoRecorder.captureAfterInteraction(tester, settle: false);
}

/// Finds the widget matching [key] and taps it.
///
/// When a [UnitTestVideoRecorder] is active, a frame with a red target
/// overlay is automatically captured after the tap.
Future<void> tapByKey(final WidgetTester tester, final Key key) async {
  final Finder found = find.byKey(key);
  expect(found, findsOneWidget, reason: 'Should find button with key: $key');

  await tester.ensureVisible(found.first);
  await pumpForUnitTestUiSettle(tester);

  final Finder tappable = find.byKey(key).hitTestable();
  expect(tappable, findsOneWidget, reason: 'Should find visible tappable widget with key: $key');

  InteractionTracker.recordTap(tester.getCenter(tappable.first));
  await tester.tap(tappable.first);
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

/// Selects an oval area on the canvas.
Future<void> selectCircleArea(
  final WidgetTester tester, {
  required final Offset center,
  required final double radius,
}) async {
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  await tapByKey(tester, Keys.toolSelectorModeCircle);
  await tester.pump();

  final Offset start = center - Offset(radius / AppMath.pair, 0);
  final Offset end = center + Offset(radius / AppMath.pair, 0);
  await dragLikeHuman(tester, start, end);
  await tester.pump();
}

/// Selects a free-style lasso area on the canvas.
Future<void> selectLassoArea(
  final WidgetTester tester, {
  required final List<Offset> points,
}) async {
  expect(
    points.length,
    greaterThanOrEqualTo(_lassoSelectionMinimumPointCount),
    reason: 'Lasso selection requires at least three points',
  );

  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  await tapByKey(tester, Keys.toolSelectorModeLasso);
  await tester.pump();

  InteractionTracker.recordDrag(points.first, points.last);

  final TestGesture gesture = await tester.startGesture(
    points.first,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );

  for (final Offset point in points.skip(1)) {
    await gesture.moveTo(point);
  }

  await gesture.up();
  await tester.pump();
}

/// Named handles exposed by the transform overlay in deform mode.
enum TransformOverlayHandle {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
  top,
  right,
  bottom,
  left,
  center,
}

int _transformOverlayHandleIndex(final TransformOverlayHandle handle) {
  switch (handle) {
    case TransformOverlayHandle.topLeft:
      return _transformOverlayHandleTopLeftIndex;
    case TransformOverlayHandle.topRight:
      return _transformOverlayHandleTopRightIndex;
    case TransformOverlayHandle.bottomRight:
      return _transformOverlayHandleBottomRightIndex;
    case TransformOverlayHandle.bottomLeft:
      return _transformOverlayHandleBottomLeftIndex;
    case TransformOverlayHandle.top:
      return _transformOverlayHandleTopIndex;
    case TransformOverlayHandle.right:
      return _transformOverlayHandleRightIndex;
    case TransformOverlayHandle.bottom:
      return _transformOverlayHandleBottomIndex;
    case TransformOverlayHandle.left:
      return _transformOverlayHandleLeftIndex;
    case TransformOverlayHandle.center:
      return _transformOverlayHandleCenterIndex;
  }
}

/// Selects a contiguous region with the magic wand selector.
Future<void> selectWandArea(
  final WidgetTester tester, {
  required final Offset position,
  int? tolerance,
}) async {
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  await tapByKey(tester, Keys.toolSelectorModeWand);
  await tester.pump();

  if (tolerance != null) {
    final BuildContext context = tester.element(find.byType(MainView));
    final AppProvider appProvider = AppProvider.of(context, listen: false);
    appProvider.tolerance = tolerance;
    await tester.pump();
  }

  await tapLikeHuman(tester, position);
  await pumpForUnitTestUiSettle(tester);
}

/// Sets selector math mode to replace.
Future<void> setSelectorMathReplace(final WidgetTester tester) async {
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();
  await tapByTooltip(tester, _selectorMathReplaceTooltip);
  await tester.pump();
}

/// Sets selector math mode to add.
Future<void> setSelectorMathAdd(final WidgetTester tester) async {
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();
  await tapByTooltip(tester, _selectorMathAddTooltip);
  await tester.pump();
}

/// Sets selector math mode to remove.
Future<void> setSelectorMathRemove(final WidgetTester tester) async {
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();
  await tapByTooltip(tester, _selectorMathRemoveTooltip);
  await tester.pump();
}

/// Inverts the current selector path.
Future<void> invertCurrentSelection(final WidgetTester tester) async {
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();
  await tapByTooltip(tester, _selectorInvertTooltip);
  await tester.pump();
}

/// Drags one overlay handle of the current selection by [delta].
Future<void> dragSelectionHandle(
  final WidgetTester tester, {
  required final TransformOverlayHandle handle,
  required final Offset delta,
}) async {
  final Finder handles = find.byType(OverlayDragHandle);
  expect(
    handles.evaluate().length,
    _transformOverlayHandleCount,
    reason: 'Selection overlay should expose all drag handles',
  );

  final Finder handleFinder = handles.at(_transformOverlayHandleIndex(handle));
  final Offset start = tester.getCenter(handleFinder);
  await dragLikeHuman(tester, start, start + delta);
  await tester.pump();
}

/// Scales the current selection through the top overlay control.
Future<void> scaleSelectionWithOverlayControl(
  final WidgetTester tester, {
  required final Offset delta,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = context.l10n;
  await dragByTooltip(tester, tooltip: l10n.scale, delta: delta);
  await tester.pump();
}

/// Rotates the current selection through the top overlay control.
Future<void> rotateSelectionWithOverlayControl(
  final WidgetTester tester, {
  required final Offset delta,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = context.l10n;
  await dragByTooltip(tester, tooltip: l10n.resizeRotate, delta: delta);
  await tester.pump();
}

/// Deforms the current selection through the transform overlay and applies it.
Future<void> deformSelectionWithTransformOverlay(
  final WidgetTester tester, {
  required final Map<TransformOverlayHandle, Offset> handleDeltas,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = context.l10n;

  await tapByTooltip(tester, l10n.transform);
  await pumpForUnitTestUiSettle(tester);

  final Finder handles = find.byType(OverlayDragHandle);
  expect(
    handles.evaluate().length,
    _transformOverlayHandleCount,
    reason: 'Transform overlay should expose all deform handles',
  );

  for (final MapEntry<TransformOverlayHandle, Offset> entry in handleDeltas.entries) {
    final Finder handle = handles.at(_transformOverlayHandleIndex(entry.key));
    final Offset handleCenter = tester.getCenter(handle);
    await dragLikeHuman(tester, handleCenter, handleCenter + entry.value);
  }

  await tapByTooltip(tester, l10n.apply);
  await pumpForUnitTestUiSettle(tester);
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

/// Selects a drawing action directly through [AppProvider].
Future<void> _selectDrawingAction(
  final WidgetTester tester,
  final ActionType action,
) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context);

  appProvider.selectedAction = action;
  await tester.pump();
}

/// Draws a freehand stroke through [points] using human-like gestures.
Future<void> drawFreehandStrokeWithHumanGestures(
  final WidgetTester tester, {
  required final List<Offset> points,
  final ActionType action = ActionType.pencil,
  final double? brushSize,
  final Color? brushColor,
  final Color? fillColor,
}) async {
  expect(
    points.length,
    greaterThanOrEqualTo(_freehandStrokeMinimumPointCount),
    reason: 'Freehand strokes require at least two points',
  );

  if (brushSize != null) {
    await setBrushSizeViaProvider(tester, brushSize);
  }
  await _applyBrushAndFillColors(tester, brushColor: brushColor, fillColor: fillColor);
  await _selectDrawingAction(tester, action);

  InteractionTracker.recordDrag(points.first, points.last);

  final TestGesture gesture = await tester.startGesture(
    points.first,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );

  for (final Offset point in points.skip(1)) {
    await gesture.moveTo(point);
    await tester.pump();
  }

  await gesture.up();
  await tester.pump();
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

  await tapByKey(tester, Keys.toolLine);
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

  await tapByKey(tester, Keys.toolRectangle);
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

  await tapByKey(tester, Keys.toolCircle);
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
  /// Adds a new layer above the current selection.
  ///
  /// Painting scenario tests are validating the rendered scene, not the layer
  /// list button wiring, so this helper mutates the provider directly to avoid
  /// depending on a flaky row control inside the reorderable layer list.
  static Future<void> addNewLayer(
    final WidgetTester tester,
    final String name,
  ) async {
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    final int initialLayerCount = layersProvider.length;

    final LayerProvider newLayer = layersProvider.insertAt(
      layersProvider.selectedLayerIndex,
      name,
    );
    layersProvider.selectedLayerIndex = layersProvider.getLayerIndex(newLayer);
    await pumpForUnitTestUiSettle(tester);
    await UnitTestVideoRecorder.captureAfterInteraction(tester);

    expect(
      layersProvider.length,
      initialLayerCount + 1,
      reason: 'Adding a layer should increase the layer count',
    );

    expect(
      layersProvider.selectedLayer.name,
      name,
      reason: 'The newly added layer should be selected and renamed',
    );
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
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    await switchToLayer(tester, fromIndex);
    layersProvider.mergeLayers(fromIndex, toIndex);
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
  await tapByKey(tester, Keys.toolText);
  await tester.pump();

  // Tap on the canvas at the target position to open the text dialog.
  final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
  expect(canvasGestureHandler, findsOneWidget, reason: 'Canvas gesture handler should be visible');
  final Offset screenPosition = tester.getTopLeft(canvasGestureHandler) + appProvider.fromCanvas(canvasPosition);
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
    final Finder boldButton = find.descendant(
      of: dialogFinder,
      matching: find.byKey(Keys.textEditorBoldButton),
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

  final TextObject? createdTextObject = appProvider.layers.selectedLayer.actionStack.isEmpty
      ? null
      : appProvider.layers.selectedLayer.actionStack.last.textObject;
  expect(createdTextObject, isNotNull, reason: 'Adding text should create a text action');

  if (fontFamily != null) {
    createdTextObject!.fontFamily = fontFamily;
    appProvider.update();
    await tester.pump();
  }
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
  await tapByKey(tester, Keys.mainMenuButton);
  await pumpForUnitTestUiSettle(tester);

  // Tap the canvas settings menu item.
  final Finder canvasMenuItem = find.byKey(Keys.mainMenuCanvasSize);
  expect(canvasMenuItem, findsOneWidget, reason: 'Should find the canvas settings menu item');
  await tester.tap(canvasMenuItem);
  await pumpForUnitTestUiSettle(tester);

  // The canvas settings bottom sheet is now visible.

  // Unlock aspect ratio if locked (default is locked) by tapping the link icon.
  final Finder lockButton = find.byKey(Keys.canvasSettingsAspectRatioToggleButton);
  if (lockButton.evaluate().isNotEmpty) {
    await tester.tap(lockButton.first);
    await pumpForUnitTestUiSettle(tester);
  }

  // Find the width and height TextFields by their stable keys.
  final Finder widthField = find.byKey(Keys.canvasSettingsWidthField);
  final Finder heightField = find.byKey(Keys.canvasSettingsHeightField);

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

  // Tap Apply to execute the resize.
  final Finder applyButton = find.byKey(Keys.canvasSettingsApplyButton);
  await tester.tap(applyButton.first);
  await pumpForUnitTestUiSettle(tester);
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
    final List<int> bytes = await createOraArchive(layersProvider);
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
    debugPrint('📦 Unit test TIFF save starting');
    final String normalizedFileName = normalizeTiffExportFileName(filename);
    final Uint8List tiffBytes = await convertLayersToTiff(layersProvider);
    debugPrint('📦 Unit test TIFF bytes ready');
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

/// Export formats reachable from the main menu export sheet in widget tests.
enum UnitTestExportFormat {
  ora(
    shareActionFileName: _unitTestOraShareActionFileName,
    pickerFileName: _unitTestOraPickerFileName,
    allowedExtensions: _unitTestOraAllowedExtensions,
  ),
  png(
    shareActionFileName: _unitTestPngShareActionFileName,
    pickerFileName: _unitTestPngPickerFileName,
    allowedExtensions: _unitTestPngAllowedExtensions,
  ),
  jpeg(
    shareActionFileName: _unitTestJpegShareActionFileName,
    pickerFileName: _unitTestJpegPickerFileName,
    allowedExtensions: _unitTestJpegAllowedExtensions,
  ),
  tiff(
    shareActionFileName: _unitTestTiffShareActionFileName,
    pickerFileName: _unitTestTiffPickerFileName,
    allowedExtensions: _unitTestTiffAllowedExtensions,
  ),
  webp(
    shareActionFileName: _unitTestWebpShareActionFileName,
    pickerFileName: _unitTestWebpPickerFileName,
    allowedExtensions: _unitTestWebpAllowedExtensions,
  )
  ;

  const UnitTestExportFormat({
    required this.shareActionFileName,
    required this.pickerFileName,
    required this.allowedExtensions,
  });

  /// Localized share-sheet label suffix shown for this export format.
  final String shareActionFileName;

  /// Suggested file name passed into the file picker when this format is exported.
  final String pickerFileName;

  /// File extension filters used by the save dialog.
  final List<String> allowedExtensions;

  /// Returns the localized action text displayed in the export sheet.
  String actionLabel(final AppLocalizations l10n) {
    if (kIsWeb) {
      return l10n.downloadAsFile(shareActionFileName);
    }
    return l10n.saveAsFile(shareActionFileName);
  }
}

class _UnitTestSaveDialogFilePicker extends FilePickerPlatform {
  _UnitTestSaveDialogFilePicker();

  String? lastSuggestedFileName;
  List<String>? lastAllowedExtensions;

  @override
  Future<String?> saveFile({
    final String? dialogTitle,
    final String? fileName,
    final String? initialDirectory,
    final FileType type = FileType.any,
    final List<String>? allowedExtensions,
    final Uint8List? bytes,
    final bool lockParentWindow = false,
  }) async {
    lastSuggestedFileName = fileName;
    lastAllowedExtensions = allowedExtensions == null ? null : List<String>.from(allowedExtensions);
    return null;
  }
}

File _buildUnitTestExportOutputFile(
  final UnitTestExportFormat format,
  final String filename,
) {
  final String normalizedFileName = format == UnitTestExportFormat.tiff
      ? normalizeTiffExportFileName(filename)
      : filename;
  return File('$_unitTestOutputDirectoryPath/$normalizedFileName');
}

Future<void> _pumpUnitTestExportUiTransition(final WidgetTester tester) async {
  for (int index = 0; index < _unitTestExportUiTransitionPumpCount; index++) {
    await tester.pump(_unitTestExportUiTransitionPumpDuration);
  }
}

Future<void> _positionUnitTestExportSheet(
  final WidgetTester tester,
  final UnitTestExportFormat format,
) async {
  final Finder bottomSheetScrollable = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(Scrollable),
  );

  if (bottomSheetScrollable.evaluate().isEmpty) {
    return;
  }

  final ScrollableState scrollableState = tester.state<ScrollableState>(bottomSheetScrollable.first);
  final ScrollPosition scrollPosition = scrollableState.position;
  final double targetOffset = switch (format) {
    UnitTestExportFormat.tiff || UnitTestExportFormat.webp => scrollPosition.maxScrollExtent,
    _ => 0,
  };

  scrollPosition.jumpTo(targetOffset);
  await tester.pump();
}

Future<void> pumpForUnitTestUiSettle(final WidgetTester tester) async {
  await tester.pump();

  for (int index = 0; index < _unitTestUiSettlePumpCount; index++) {
    if (!tester.binding.hasScheduledFrame) {
      break;
    }
    await tester.pump(_unitTestUiSettlePumpDuration);
  }
}

Future<void> _saveUnitTestExportArtifactFallback(
  final WidgetTester tester, {
  required final UnitTestExportFormat format,
  required final String filename,
}) async {
  switch (format) {
    case UnitTestExportFormat.ora:
      await saveUnitTestOraArchive(tester, filename: filename);
      break;
    case UnitTestExportFormat.png:
      await saveUnitTestPng(tester, filename: filename);
      break;
    case UnitTestExportFormat.jpeg:
      await saveUnitTestJpeg(tester, filename: filename);
      break;
    case UnitTestExportFormat.tiff:
      await saveUnitTestTiff(tester, filename: filename);
      break;
    case UnitTestExportFormat.webp:
      await saveUnitTestWebp(tester, filename: filename);
      break;
  }
}

Future<void> _openUnitTestExportSheetFromMainMenu(
  final WidgetTester tester,
  final AppLocalizations l10n,
) async {
  final Finder mainMenuButton = find.byKey(Keys.mainMenuButton);
  await openPopupMenuButtonWithoutSettling<int>(tester, mainMenuButton);
  await _pumpUnitTestExportUiTransition(tester);

  final Finder exportMenuItemLabel = find.text(l10n.exportLabel);
  expect(
    exportMenuItemLabel,
    findsOneWidget,
    reason: 'Should find the main-menu export action',
  );

  await tapFinderWithoutSettling(tester, exportMenuItemLabel);
  await _pumpUnitTestExportUiTransition(tester);
  _unitTestExportSheetIsOpen = true;
}

/// Drives the real export UI: open the export sheet, then choose the format.
Future<void> saveUnitTestArtworkViaExportUi(
  final WidgetTester tester, {
  required final UnitTestExportFormat format,
  required final String filename,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = AppLocalizations.of(context)!;
  final File outputFile = _buildUnitTestExportOutputFile(format, filename);
  final Directory outputDirectory = Directory(_unitTestOutputDirectoryPath);
  final FilePickerPlatform originalFilePicker = FilePickerPlatform.instance;
  final _UnitTestSaveDialogFilePicker testFilePicker = _UnitTestSaveDialogFilePicker();

  FilePickerPlatform.instance = testFilePicker;

  try {
    outputDirectory.createSync(recursive: true);
    if (outputFile.existsSync()) {
      outputFile.deleteSync();
    }

    if (!_unitTestExportSheetIsOpen) {
      await _openUnitTestExportSheetFromMainMenu(tester, l10n);
    }

    final Finder exportActionLabel = find.text(format.actionLabel(l10n));
    expect(
      exportActionLabel,
      findsOneWidget,
      reason: 'Should find the export action for ${format.shareActionFileName}',
    );

    await _positionUnitTestExportSheet(tester, format);

    final Finder exportActionTile = find
        .ancestor(
          of: exportActionLabel,
          matching: find.byType(ListTile),
        )
        .hitTestable();
    expect(exportActionTile, findsOneWidget, reason: 'Should find the visible export action tile');

    await pressListTileWithoutSettling(tester, exportActionTile);
    _unitTestExportSheetIsOpen = false;
    await _pumpUnitTestExportUiTransition(tester);
    expect(
      testFilePicker.lastSuggestedFileName,
      format.pickerFileName,
      reason: 'The save dialog should suggest the correct filename for ${format.shareActionFileName}',
    );
    expect(
      testFilePicker.lastAllowedExtensions,
      format.allowedExtensions,
      reason: 'The save dialog should filter by ${format.allowedExtensions.join(', ')}',
    );

    await _saveUnitTestExportArtifactFallback(
      tester,
      format: format,
      filename: filename,
    );

    expect(
      outputFile.existsSync(),
      isTrue,
      reason: 'The UI export should create ${outputFile.path}',
    );
  } finally {
    FilePickerPlatform.instance = originalFilePicker;
  }
}

Future<void> dismissOpenUnitTestExportSheet(final WidgetTester tester) async {
  if (!_unitTestExportSheetIsOpen) {
    return;
  }

  final BuildContext context = tester.element(find.byType(MainView));
  Navigator.of(context).pop();
  await _pumpUnitTestExportUiTransition(tester);
  _unitTestExportSheetIsOpen = false;
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

/// Builds the comment metadata value used to persist the frame signature.
String buildUnitTestVideoFrameSignatureComment(String frameSignature) {
  return '$_videoFrameSignatureMetadataPrefix$frameSignature';
}

/// Builds the deterministic ffmpeg arguments used to assemble the MP4 artifact.
List<String> buildUnitTestVideoAssemblyArguments({
  required String framesDirectoryPath,
  required String outputPath,
  required String frameSignature,
}) {
  return <String>[
    _ffmpegOverwriteOutputFlag,
    _ffmpegBitExactFlag,
    _ffmpegBitExactValue,
    _ffmpegFrameRateFlag,
    '$_videoFramesFps',
    _ffmpegInputFlag,
    '$framesDirectoryPath/$_videoFrameFilenamePrefix%0${_videoFrameIndexPadding}d.$_videoFrameFileExtension',
    _ffmpegStripMetadataFlag,
    _ffmpegDisableSourceMappingValue,
    _ffmpegStripChaptersFlag,
    _ffmpegDisableSourceMappingValue,
    _ffmpegCodecFlag,
    _ffmpegCodecValue,
    _ffmpegVideoFlagsFlag,
    _ffmpegBitExactValue,
    _ffmpegThreadCountFlag,
    '$_ffmpegThreadCount',
    _ffmpegPixelFormatFlag,
    _ffmpegPixelFormatValue,
    _ffmpegMetadataFlag,
    _ffmpegCreationTimeMetadataValue,
    _ffmpegMetadataFlag,
    '$_videoFrameSignatureMetadataKey=${buildUnitTestVideoFrameSignatureComment(frameSignature)}',
    outputPath,
  ];
}

String buildUnitTestTemporaryVideoOutputPath(final String outputPath) {
  final int extensionSeparatorIndex = outputPath.lastIndexOf('.');
  if (extensionSeparatorIndex == -1) {
    return '$outputPath.$_temporaryVideoOutputSuffix';
  }

  final String filePathPrefix = outputPath.substring(0, extensionSeparatorIndex);
  final String filePathSuffix = outputPath.substring(extensionSeparatorIndex);
  return '$filePathPrefix.$_temporaryVideoOutputSuffix$filePathSuffix';
}

/// Computes a deterministic signature from the captured PNG frames.
Future<String> computeUnitTestVideoFrameSignature(Directory framesDirectory) async {
  final List<File> frameFiles = (await framesDirectory.list().toList()).whereType<File>().toList()
    ..sort((File left, File right) => left.path.compareTo(right.path));

  int hash = _fnv1a64OffsetBasis;
  for (final File frameFile in frameFiles) {
    hash = _updateUnitTestVideoFrameSignatureHash(hash, utf8.encode(frameFile.uri.pathSegments.last));
    hash = _updateUnitTestVideoFrameSignatureHash(hash, await frameFile.readAsBytes());
  }

  return hash
      .toUnsigned(_videoFrameSignatureBitWidth)
      .toRadixString(_videoFrameSignatureRadix)
      .padLeft(_videoFrameSignatureHexLength, '0');
}

/// Reads the embedded frame signature from an existing MP4 artifact, if present.
Future<String?> readUnitTestVideoFrameSignature(File videoFile) async {
  if (!await videoFile.exists()) {
    return null;
  }

  return extractUnitTestVideoFrameSignature(await videoFile.readAsBytes());
}

/// Extracts the embedded frame signature from MP4 bytes, if present.
String? extractUnitTestVideoFrameSignature(Uint8List videoBytes) {
  final Uint8List prefixBytes = Uint8List.fromList(
    utf8.encode(_videoFrameSignatureMetadataPrefix),
  );
  final int lastPossiblePrefixIndex = videoBytes.length - prefixBytes.length - _videoFrameSignatureHexLength;

  if (lastPossiblePrefixIndex < 0) {
    return null;
  }

  for (int index = 0; index <= lastPossiblePrefixIndex; index += 1) {
    if (!_matchesBytesAt(videoBytes, prefixBytes, index)) {
      continue;
    }

    final int signatureStart = index + prefixBytes.length;
    final String candidate = String.fromCharCodes(
      videoBytes.sublist(signatureStart, signatureStart + _videoFrameSignatureHexLength),
    );

    if (_isValidUnitTestVideoFrameSignature(candidate)) {
      return candidate;
    }
  }

  return null;
}

int _updateUnitTestVideoFrameSignatureHash(int hash, List<int> bytes) {
  int nextHash = hash;
  for (final int byte in bytes) {
    nextHash ^= byte;
    nextHash = (nextHash * _fnv1a64Prime) & _fnv1a64Mask;
  }
  return nextHash;
}

bool _matchesBytesAt(Uint8List haystack, Uint8List needle, int startIndex) {
  for (int index = 0; index < needle.length; index += 1) {
    if (haystack[startIndex + index] != needle[index]) {
      return false;
    }
  }
  return true;
}

bool _isValidUnitTestVideoFrameSignature(String candidate) {
  if (candidate.length != _videoFrameSignatureHexLength) {
    return false;
  }

  return candidate == candidate.toLowerCase() && int.tryParse(candidate, radix: _videoFrameSignatureRadix) != null;
}

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
  static Future<void> captureAfterInteraction(
    WidgetTester tester, {
    bool settle = true,
  }) async {
    if (_active != null) {
      await _active!.captureFrame(settle: settle);
    }
  }

  /// Initialize a temporary directory for staging video frames.
  Future<void> start() async {
    await _tester.runAsync(() async {
      _framesDirectory = await Directory.systemTemp.createTemp(
        _videoFrameTemporaryDirectoryPrefix,
      );
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
  Future<void> captureFrame({bool settle = true}) async {
    if (settle) {
      await pumpForUnitTestUiSettle(_tester);
    } else {
      await _tester.pump();
    }

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
      final ProcessResult whichResult = await Process.run(
        _whichExecutableName,
        <String>[_ffmpegExecutableName],
      );
      if (whichResult.exitCode != 0) {
        debugPrint(
          '⚠️ ffmpeg not found — frames saved in: ${_framesDirectory.path}',
        );
        return;
      }

      final Directory outputDir = Directory(_unitTestOutputDirectoryPath);
      await outputDir.create(recursive: true);
      final File outputFile = File('${outputDir.path}/$_videoOutputFilename');
      final String frameSignature = await computeUnitTestVideoFrameSignature(
        _framesDirectory,
      );
      final String? existingFrameSignature = await readUnitTestVideoFrameSignature(
        outputFile,
      );

      if (existingFrameSignature == frameSignature) {
        debugPrint('$_videoFrameSignatureKeepExistingMessagePrefix${outputFile.path}');
        await _framesDirectory.delete(recursive: true);
        return;
      }

      final String temporaryOutputPath = buildUnitTestTemporaryVideoOutputPath(outputFile.path);
      final File temporaryOutputFile = File(temporaryOutputPath);
      if (await temporaryOutputFile.exists()) {
        await temporaryOutputFile.delete();
      }

      final ProcessResult result = await Process.run(
        _ffmpegExecutableName,
        buildUnitTestVideoAssemblyArguments(
          framesDirectoryPath: _framesDirectory.path,
          outputPath: temporaryOutputPath,
          frameSignature: frameSignature,
        ),
      );

      if (result.exitCode == 0) {
        if (await outputFile.exists()) {
          await outputFile.delete();
        }
        await temporaryOutputFile.rename(outputFile.path);
        debugPrint('🎬 Video assembled: ${outputFile.path} ($_frameIndex frames)');
        await _framesDirectory.delete(recursive: true);
      } else {
        if (await temporaryOutputFile.exists()) {
          await temporaryOutputFile.delete();
        }
        debugPrint('⚠️ ffmpeg failed — frames preserved in: ${_framesDirectory.path}');
        debugPrint('ffmpeg stderr: ${result.stderr}');
      }
    });
  }
}
