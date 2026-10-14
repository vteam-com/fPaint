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
  compactPixelBrushLayerHistory(targetLayer: layer, maxGestureCount: _maxGestureCount);
}

void main() {
  group('compactPixelBrushLayerHistory', () {
    test('keeps the layer content when it flattens past the gesture cap', () async {
      final LayerProvider layer = LayerProvider(name: 'Clouds', size: _layerSize, onThumbnailChanged: () {});
      layer.appendDrawingAction(
        RegionAction(
          positions: <Offset>[_baseFillRect.topLeft, _baseFillRect.bottomRight],
          fillColor: _baseFillColor,
          path: ui.Path()..addRect(_baseFillRect),
        ),
      );

      for (int stroke = 0; stroke < _strokeCount; stroke++) {
        await _commitSmudgePatch(layer, stroke);
      }

      expect(
        layer.actionStack.map((UserActionDrawing action) => action.action),
        <ActionType>[ActionType.image],
        reason: 'Exceeding the gesture cap should flatten the history into one image',
      );
      final ui.Image flattened = layer.toImageForStorage(_layerSize);
      expect(
        await _countOpaquePixels(flattened),
        (_baseFillRect.width * _baseFillRect.height).toInt(),
        reason: 'Flattening must preserve every painted pixel, not erase the layer',
      );
      flattened.dispose();
    });

    test('leaves the history alone while under the gesture cap', () async {
      final LayerProvider layer = LayerProvider(name: 'Clouds', size: _layerSize, onThumbnailChanged: () {});
      for (int stroke = 0; stroke < _maxGestureCount; stroke++) {
        await _commitSmudgePatch(layer, stroke);
      }

      expect(layer.actionStack.length, _maxGestureCount);
      expect(
        layer.actionStack.every((UserActionDrawing action) => isPixelBrushPersistedActionType(action.action)),
        isTrue,
      );
    });
  });
}
