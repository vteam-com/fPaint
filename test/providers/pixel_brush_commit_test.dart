import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/pixel_brush_commit.dart';
import 'package:material_ui/material_ui.dart';

const Size _layerSize = Size(64, 64);
const Rect _baseFillRect = Rect.fromLTWH(0, 0, 32, 64);
const Color _baseFillColor = Color(0xFF3388AA);
const Color _patchColor = Color(0xFF992222);
const double _patchSide = 8;
const int _maxGestureCount = 3;
const int _strokeCount = _maxGestureCount + 1;
const int _rgbaBytesPerPixel = 4;
const int _alphaChannelOffset = 3;

Future<int> _countOpaquePixels(ui.Image image) async {
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  int count = 0;
  for (int offset = _alphaChannelOffset; offset < bytes!.lengthInBytes; offset += _rgbaBytesPerPixel) {
    if (bytes.getUint8(offset) > 0) {
      count++;
    }
  }
  return count;
}

/// Commits one smudge patch the way [AppProviderPixelBrush] does on pointer-up:
/// replace the stack with the restore snapshot plus the patch, then compact.
Future<void> _commitSmudgePatch(LayerProvider layer, int strokeIndex) async {
  final ImagePlacementLayerRestoreState restoreState = ImagePlacementLayerRestoreState(
    layerIndex: 0,
    layerState: layer.captureSnapshot(),
  );
  final ui.Image patch = await renderCanvasImage(
    width: _patchSide.toInt(),
    height: _patchSide.toInt(),
    draw: (ui.Canvas canvas) => canvas.drawRect(
      const Rect.fromLTWH(0, 0, _patchSide, _patchSide),
      Paint()..color = _patchColor,
    ),
  );
  applyPixelBrushPatchToLayer(
    restoreState: restoreState,
    targetLayer: layer,
    patch: PixelBrushLayerPatch(
      bounds: Rect.fromLTWH(strokeIndex * _patchSide, 0, _patchSide, _patchSide),
      image: patch,
    ),
    mode: PixelBrushMode.smudge,
    retainCache: true,
  );
  layer.invalidateFullResCache();
  await compactPixelBrushLayerHistory(targetLayer: layer, maxGestureCount: _maxGestureCount);
}

/// Appends an unrelated (non-pixel-brush) fill, splitting runs of patches.
void _appendFill(LayerProvider layer, Rect rect) {
  layer.appendDrawingAction(
    RegionAction(
      positions: <Offset>[rect.topLeft, rect.bottomRight],
      fillColor: _baseFillColor,
      path: ui.Path()..addRect(rect),
    ),
  );
}

Future<Uint8List> _layerBytes(LayerProvider layer) async {
  final ui.Image image = layer.toImageForStorage(_layerSize);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// Appends [patchAction] to [layer] without compacting (the reference stack).
Future<void> _commitSmudgePatchWithoutCompaction(LayerProvider layer, UserActionDrawing patchAction) async {
  layer.actionStack.add(patchAction);
}

void main() {
  group('compactPixelBrushLayerHistory', () {
    test('merges a run of consecutive patches over their union', () async {
      final LayerProvider layer = LayerProvider(name: 'Clouds', size: _layerSize, onThumbnailChanged: () {});
      _appendFill(layer, _baseFillRect);
      for (int stroke = 0; stroke < _strokeCount; stroke++) {
        await _commitSmudgePatch(layer, stroke);
      }

      expect(
        layer.actionStack.map((UserActionDrawing action) => action.action),
        <ActionType>[ActionType.region, ActionType.smudge],
        reason: 'The consecutive patches collapse into one patch above the untouched fill',
      );
      final ImageAction mergedPatch = layer.actionStack.last as ImageAction;
      expect(mergedPatch.image.width, (_strokeCount * _patchSide).toInt());
      expect(mergedPatch.image.height, _patchSide.toInt());
    });

    test('compaction leaves every pixel unchanged', () async {
      final LayerProvider layer = LayerProvider(name: 'Clouds', size: _layerSize, onThumbnailChanged: () {});
      _appendFill(layer, _baseFillRect);
      final LayerProvider uncompacted = LayerProvider(name: 'Ref', size: _layerSize, onThumbnailChanged: () {});
      for (int stroke = 0; stroke < _strokeCount; stroke++) {
        await _commitSmudgePatch(layer, stroke);
        await _commitSmudgePatchWithoutCompaction(uncompacted, layer.actionStack.last);
      }
      uncompacted.actionStack.insert(0, layer.actionStack.first);

      expect(layer.actionStack.length, lessThan(uncompacted.actionStack.length));
      expect(await _layerBytes(layer), equals(await _layerBytes(uncompacted)));
    });

    test('patches interleaved with other actions fall back to a full flatten', () async {
      final LayerProvider layer = LayerProvider(name: 'Clouds', size: _layerSize, onThumbnailChanged: () {});
      for (int stroke = 0; stroke < _maxGestureCount; stroke++) {
        await _commitSmudgePatch(layer, stroke);
        _appendFill(layer, Rect.fromLTWH(stroke * _patchSide, _patchSide, _patchSide, _patchSide));
      }
      final int opaqueBefore = await _countOpaquePixels(layer.toImageForStorage(_layerSize));

      await _commitSmudgePatch(layer, _maxGestureCount);

      expect(
        layer.actionStack.map((UserActionDrawing action) => action.action),
        <ActionType>[ActionType.image],
        reason: 'With no adjacent patches to merge, the history flattens into one image',
      );
      expect(
        await _countOpaquePixels(layer.toImageForStorage(_layerSize)),
        opaqueBefore + (_patchSide * _patchSide).toInt(),
        reason: 'Flattening must preserve every painted pixel, not erase the layer',
      );
    });

    test('a compaction that races a new edit is discarded', () async {
      final LayerProvider layer = LayerProvider(name: 'Clouds', size: _layerSize, onThumbnailChanged: () {});
      for (int stroke = 0; stroke < _maxGestureCount; stroke++) {
        await _commitSmudgePatch(layer, stroke);
      }
      final ImageAction lastPatch = layer.actionStack.last as ImageAction;
      layer.actionStack.add(
        ImageAction.placed(
          action: ActionType.smudge,
          bounds: const Rect.fromLTWH(_maxGestureCount * _patchSide, 0, _patchSide, _patchSide),
          image: lastPatch.image,
        ),
      );

      final Future<void> compaction = compactPixelBrushLayerHistory(
        targetLayer: layer,
        maxGestureCount: _maxGestureCount,
      );
      _appendFill(layer, _baseFillRect);
      await compaction;

      expect(layer.actionStack.length, _strokeCount + 1);
    });

    test('leaves the history alone while under the gesture cap', () async {
      final LayerProvider layer = LayerProvider(name: 'Clouds', size: _layerSize, onThumbnailChanged: () {});
      for (int stroke = 0; stroke < _maxGestureCount; stroke++) {
        await _commitSmudgePatch(layer, stroke);
      }

      expect(layer.actionStack.length, _maxGestureCount);
      expect(
        layer.actionStack.every((UserActionDrawing action) => action.action.isPixelBrush),
        isTrue,
      );
    });
  });
}
