// ignore_for_file: use_build_context_synchronously

import 'dart:io';
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
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/services/fill_service.dart';
import 'package:fpaint/widgets/main_view.dart';
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
Future<void> tapLikeHuman(
  final WidgetTester tester,
  final Offset position,
) async {
  final TestGesture gesture = await tester.startGesture(
    position,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );
  await gesture.up();
}

/// Finds the widget matching [key] and taps it.
Future<void> tapByKey(final WidgetTester tester, final Key key) async {
  final Finder found = find.byKey(key);
  expect(found, findsOneWidget, reason: 'Should find button with key: $key');
  await tester.tap(found.first);
  await tester.pump();
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
/// Uses [FillService] directly inside [WidgetTester.runAsync] because
/// the pixel-level flood fill requires real async I/O (`image.toByteData`)
/// that cannot complete in the fake async zone of widget tests.
Future<void> performFloodFillSolid(
  final WidgetTester tester, {
  required final Offset position,
  required final Color color,
  int? tolerance,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
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

  await tester.pump();
}

/// Performs a solid flood fill at the given [canvasPosition] (in canvas pixel
/// coordinates, not screen coordinates).
///
/// Use this instead of [performFloodFillSolid] when screen-to-canvas conversion
/// via [AppProvider.toCanvas] is unreliable (e.g. after zoom-out).
Future<void> performFloodFillSolidAtCanvasPosition(
  final WidgetTester tester, {
  required final Offset canvasPosition,
  required final Color color,
  int? tolerance,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

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

  await tester.pump();
}

/// Performs a gradient flood fill with the specified [gradientMode] and [gradientPoints].
///
/// Uses [FillService] directly inside [WidgetTester.runAsync] for the same
/// reason as [performFloodFillSolid].
Future<void> performFloodFillGradient(
  final WidgetTester tester, {
  required final FillMode gradientMode,
  required final List<GradientPoint> gradientPoints,
  Offset Function(Offset)? toCanvas,
}) async {
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

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

  await tester.pump();
}

// ---------------------------------------------------------------------------
// Layer management
// ---------------------------------------------------------------------------

/// Helpers for managing layers during painting tests.
class PaintingLayerHelpers {
  /// Adds a new layer above the current selection and renames it.
  static Future<void> addNewLayer(
    final WidgetTester tester,
    final String name,
  ) async {
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    final int currentIndex = layersProvider.selectedLayerIndex;

    layersProvider.insertAt(currentIndex);
    final LayerProvider newLayer = layersProvider.get(currentIndex);
    layersProvider.selectedLayerIndex = layersProvider.getLayerIndex(newLayer);
    await tester.pump();

    layersProvider.selectedLayer.name = name;
    layersProvider.update();
    await tester.pump();
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
// Video recording
// ---------------------------------------------------------------------------

/// Records numbered PNG frames at each test checkpoint and assembles them
/// into an MP4 video using ffmpeg when [stop] is called.
///
/// All frame capture uses [WidgetTester.runAsync] so that
/// [RenderRepaintBoundary.toImage] completes in the fake async zone.
class UnitTestVideoRecorder {
  UnitTestVideoRecorder(this._tester);

  final WidgetTester _tester;
  int _frameIndex = 0;
  int _frameErrors = 0;
  late final Directory _framesDirectory;

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
    debugPrint('🎬 Video recorder started — frames: ${_framesDirectory.path}');
  }

  /// Captures the current app screenshot boundary as a numbered PNG frame.
  Future<void> captureFrame() async {
    await _tester.pumpAndSettle();

    final Finder boundaryFinder = find.byKey(Keys.appScreenshotBoundary);
    if (boundaryFinder.evaluate().isEmpty) {
      _frameErrors++;
      return;
    }

    await _tester.runAsync(() async {
      try {
        final RenderRepaintBoundary boundary = _tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
        final ui.Image image = await boundary.toImage(
          pixelRatio: AppDefaults.renderedScreenshotPixelRatio,
        );
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
