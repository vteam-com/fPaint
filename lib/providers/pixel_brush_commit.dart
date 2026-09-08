import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/layer_state_snapshot.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layer_provider.dart';

/// Encapsulates a cropped raster patch and its destination bounds for
/// committing a pixel-brush stroke to a layer.
class PixelBrushLayerPatch {
  const PixelBrushLayerPatch({
    required this.bounds,
    required this.image,
  });

  final ui.Rect bounds;
  final ui.Image image;
}

/// Maps a pixel-brush [mode] to its persisted layer action type.
ActionType pixelBrushActionType(PixelBrushMode mode) {
  return mode == PixelBrushMode.smudge ? ActionType.smudge : ActionType.blurBrush;
}

/// Returns whether [actionType] is a persisted pixel-brush action.
bool isPixelBrushPersistedActionType(ActionType actionType) {
  return actionType == ActionType.smudge || actionType == ActionType.blurBrush;
}

/// Restores the target layer baseline state and applies [patch] as the latest
/// pixel-brush action for [mode].
void applyPixelBrushPatchToLayer({
  required ImagePlacementLayerRestoreState restoreState,
  required LayerProvider targetLayer,
  required PixelBrushLayerPatch patch,
  required PixelBrushMode mode,
  bool retainCache = false,
}) {
  final LayerStateSnapshot layerState = restoreState.layerState;
  targetLayer.actionStack
    ..clear()
    ..addAll(layerState.actions);
  targetLayer.redoStack.clear();
  targetLayer.backgroundColor = layerState.backgroundColor;
  targetLayer.blendMode = layerState.blendMode;
  targetLayer.opacity = layerState.opacity;
  targetLayer.hasChanged = layerState.hasChanged;
  // When the caller supplies an incrementally-composited cache, append without
  // clearing it (a full-stack replay + thumbnail rebuild per commit is the
  // smudge/blur perf bottleneck); otherwise fall back to the cache-clearing
  // append.
  final void Function(UserActionDrawing) append = retainCache
      ? targetLayer.appendDrawingActionRetainingCache
      : targetLayer.appendDrawingAction;
  // A single patch action, rendered with BlendMode.src, fully REPLACES its
  // region (see [_renderAction] for smudge/blurBrush). No separate `cut` clear:
  // a clear-then-srcOver pair leaves a sub-1 alpha ring at anti-aliased edges
  // when replayed under the display cache's fractional scale — the white
  // rectangle around the stroke. src replaces cleanly at any scale.
  append(
    ImageAction(
      action: pixelBrushActionType(mode),
      positions: <ui.Offset>[patch.bounds.topLeft, patch.bounds.bottomRight],
      brush: MyBrush(
        color: AppColors.transparent,
        size: AppMath.zero.toDouble(),
      ),
      fillColor: AppColors.transparent,
      image: patch.image,
    ),
  );
}

/// Compacts historical pixel-brush actions by flattening the layer when the
/// number of persisted smudge/blur gestures exceeds [maxGestureCount].
///
/// This keeps redraw cost bounded over long drawing sessions.
void compactPixelBrushLayerHistory({
  required LayerProvider targetLayer,
  required int maxGestureCount,
}) {
  int persistedPixelBrushCount = AppMath.zero;
  for (final UserActionDrawing action in targetLayer.actionStack) {
    if (isPixelBrushPersistedActionType(action.action)) {
      persistedPixelBrushCount++;
    }
  }

  if (persistedPixelBrushCount <= maxGestureCount) {
    return;
  }

  final ui.Image flattenedLayerImage = targetLayer.toImageForStorage(targetLayer.size);
  targetLayer.actionStack
    ..clear()
    ..add(
      ImageAction(
        positions: <ui.Offset>[
          ui.Offset.zero,
          ui.Offset(targetLayer.size.width, targetLayer.size.height),
        ],
        image: flattenedLayerImage,
      ),
    );
  targetLayer.redoStack.clear();
  targetLayer.hasChanged = true;
  targetLayer.clearCache();
}

/// Copies an RGBA rectangle from [pixels] into a tightly packed patch buffer.
Uint8List copyPixelBrushRect({
  required Uint8List pixels,
  required int imageWidth,
  required int left,
  required int top,
  required int width,
  required int height,
}) {
  final Uint8List result = Uint8List(width * height * AppMath.bytesPerPixel);
  final int rowByteCount = width * AppMath.bytesPerPixel;
  for (int row = AppMath.zero; row < height; row++) {
    final int sourceOffset = (((top + row) * imageWidth) + left) * AppMath.bytesPerPixel;
    final int destinationOffset = row * rowByteCount;
    result.setRange(
      destinationOffset,
      destinationOffset + rowByteCount,
      pixels,
      sourceOffset,
    );
  }
  return result;
}
