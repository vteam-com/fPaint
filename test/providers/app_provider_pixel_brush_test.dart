import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';

import '../helpers/recovery_test_helpers.dart';

const Offset _strokeStart = Offset(20, 20);
const Offset _strokeEnd = Offset(60, 40);

/// A hard colour edge the smudge stroke drags across.
const Rect _stripe = Rect.fromLTWH(0, 0, 40, 64);
const Color _stripeColor = Color(0xFF2244CC);

/// Event-loop turns allowed for the async compaction to land.
const int _compactionWaitTurns = 50;

/// Vertical spacing between successive test strokes.
const double _strokeSpacing = 4;

/// Commits one smudge stroke, offset by [index] so strokes don't coincide.
Future<void> _smudgeStroke(AppProvider appProvider, int index) async {
  final Offset shift = Offset(0, index * _strokeSpacing);
  appProvider.startPixelBrushStroke(_strokeStart + shift, PixelBrushMode.smudge);
  appProvider.extendPixelBrushStroke(_strokeEnd + shift);
  await appProvider.commitPixelBrushGesture();
}

/// Display-cache scale the canvas is projected at before the stroke.
const double _displayScale = 0.5;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('smudge history compaction keeps the source cache warm for the next stroke', () async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final AppProvider appProvider = AppProvider(preferences: preferences);
    resetAppProviderLayersForRecovery(appProvider);
    final LayerProvider layer = appProvider.layers.selectedLayer;
    layer.appendDrawingAction(
      RegionAction(
        positions: <Offset>[_stripe.topLeft, _stripe.bottomRight],
        fillColor: _stripeColor,
        path: ui.Path()..addRect(_stripe),
      ),
    );
    await layer.buildDisplayCache(_displayScale);

    for (int stroke = 0; stroke <= AppInteraction.pixelBrushMaxUndoGestures; stroke++) {
      await _smudgeStroke(appProvider, stroke);
      expect(layer.actionStack.last.action, ActionType.smudge);
    }
    // Let the async history compaction land.
    for (int turn = 0; turn < _compactionWaitTurns; turn++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(
      layer.actionStack.where((UserActionDrawing action) => action.action.isPixelBrush).length,
      lessThanOrEqualTo(AppInteraction.pixelBrushMaxUndoGestures),
      reason: 'The history was compacted',
    );
    // Regression: compaction changes the action count the source-cache
    // signature tracks; a stale signature made every later stroke re-read the
    // layer from the GPU (a multi-second stall before the smudge showed).
    expect(appProvider.isSmudgeSourceCacheCurrent, isTrue);
    expect(layer.hasDisplayCache, isTrue);

    for (final LayerProvider each in appProvider.layers.list) {
      each.cancelPendingThumbnailRebuild();
    }
  });
  test('a painted Blur effect repaints the canvas as soon as it commits', () async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final AppProvider appProvider = AppProvider(preferences: preferences);
    resetAppProviderLayersForRecovery(appProvider);
    final LayerProvider layer = appProvider.layers.selectedLayer;
    layer.appendDrawingAction(
      RegionAction(
        positions: <Offset>[_stripe.topLeft, _stripe.bottomRight],
        fillColor: _stripeColor,
        path: ui.Path()..addRect(_stripe),
      ),
    );
    await layer.buildDisplayCache(_displayScale);
    appProvider.effectBrushModel.arm(SelectionEffect.blur);

    int canvasRepaints = 0;
    void countRepaint() => canvasRepaints++;
    appProvider.startEffectBrushStroke(_strokeStart);
    appProvider.extendPixelBrushStroke(_strokeEnd);
    appProvider.layers.canvasPainterRepaint.addListener(countRepaint);
    await appProvider.commitPixelBrushGesture();
    appProvider.layers.canvasPainterRepaint.removeListener(countRepaint);

    expect(layer.actionStack.last.action, ActionType.image);
    // Regression: the canvas has its own repaint boundary, and the effect
    // commit only notified the app shell, so the blur stayed invisible until
    // the 3 s thumbnail debounce repainted the canvas.
    expect(canvasRepaints, greaterThan(0));

    for (final LayerProvider each in appProvider.layers.list) {
      each.cancelPendingThumbnailRebuild();
    }
  });
}
