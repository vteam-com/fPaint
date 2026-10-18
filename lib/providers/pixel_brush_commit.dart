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
    ImageAction.placed(
      action: pixelBrushActionType(mode),
      bounds: patch.bounds,
      image: patch.image,
    ),
  );
}

/// Compacts historical pixel-brush actions once the layer holds more than
/// [maxGestureCount] smudge/blur gestures, keeping replay cost and retained
/// patch textures bounded over long sessions.
///
/// The common case — consecutive smudge/blur strokes — merges that run of
/// patches into one patch over their union bounds (cost O(union), not
/// O(canvas)). Only patches interleaved with other actions fall back to a full
/// flatten. Both render async and leave the layer's pixels unchanged, so every
/// cache (display projection, full-res raster, thumbnail) stays valid. The
/// result is discarded if the stack changed while rendering.
///
/// [applyCompaction], when given, runs the stack splice it is handed, letting
/// the caller carry state keyed on the action stack across it (the smudge
/// source-cache signature counts actions).
Future<void> compactPixelBrushLayerHistory({
  required LayerProvider targetLayer,
  required int maxGestureCount,
  void Function(void Function() splice)? applyCompaction,
}) async {
  final List<UserActionDrawing> stack = List<UserActionDrawing>.of(targetLayer.actionStack);
  final int pixelBrushCount = stack.where((UserActionDrawing action) => action.action.isPixelBrush).length;
  if (pixelBrushCount <= maxGestureCount) {
    return;
  }

  final ({int start, int end})? run = _longestPixelBrushRun(stack);
  final int start;
  final int end;
  final ImageAction replacement;
  if (run != null) {
    final ui.Rect bounds = _unionPixelBounds(stack.sublist(run.start, run.end));
    final ui.Image merged = await targetLayer.renderActionsInRegion(bounds: bounds, actionCount: run.end);
    start = run.start;
    end = run.end;
    replacement = ImageAction.placed(action: stack[run.end - AppMath.one].action, bounds: bounds, image: merged);
  } else {
    start = AppMath.zero;
    end = stack.length;
    replacement = await targetLayer.flattenToImageActionAsync();
  }

  if (!_sameActions(targetLayer.actionStack, stack)) {
    replacement.image.dispose();
    return;
  }
  void splice() {
    targetLayer.actionStack.replaceRange(start, end, <UserActionDrawing>[replacement]);
    if (run == null) {
      targetLayer.redoStack.clear();
    }
    targetLayer.hasChanged = true;
  }

  if (applyCompaction == null) {
    splice();
  } else {
    applyCompaction(splice);
  }
}

/// The longest run (at least two) of consecutive pixel-brush actions in
/// [stack], as a half-open index range, or null when none are adjacent.
({int start, int end})? _longestPixelBrushRun(List<UserActionDrawing> stack) {
  ({int start, int end})? best;
  int index = AppMath.zero;
  while (index < stack.length) {
    if (!stack[index].action.isPixelBrush) {
      index++;
      continue;
    }
    final int runStart = index;
    while (index < stack.length && stack[index].action.isPixelBrush) {
      index++;
    }
    final int length = index - runStart;
    if (length >= AppMath.pair && (best == null || length > best.end - best.start)) {
      best = (start: runStart, end: index);
    }
  }
  return best;
}

/// The whole-pixel union of the [patches]' image footprints.
ui.Rect _unionPixelBounds(List<UserActionDrawing> patches) {
  ui.Rect? union;
  for (final UserActionDrawing patch in patches) {
    final ImageAction action = patch as ImageAction;
    final ui.Rect bounds =
        action.positions.first & ui.Size(action.image.width.toDouble(), action.image.height.toDouble());
    union = union?.expandToInclude(bounds) ?? bounds;
  }
  return ui.Rect.fromLTRB(
    union!.left.floorToDouble(),
    union.top.floorToDouble(),
    union.right.ceilToDouble(),
    union.bottom.ceilToDouble(),
  );
}

/// Whether [current] still holds exactly the [expected] action instances.
bool _sameActions(List<UserActionDrawing> current, List<UserActionDrawing> expected) {
  if (current.length != expected.length) {
    return false;
  }
  for (int index = AppMath.zero; index < current.length; index++) {
    if (!identical(current[index], expected[index])) {
      return false;
    }
  }
  return true;
}
