import 'package:flutter/widgets.dart';
import 'package:fpaint/models/selector_model.dart';

/// The canvas context selector geometry needs from its host.
///
/// A narrow interface rather than the whole provider: the controller depends on
/// this abstraction, not on `AppProvider` (Dependency Inversion), which is what
/// lets the geometry be exercised without building the app state.
abstract class SelectorGeometryHost {
  /// The selection being edited.
  SelectorModel get selectorModel;

  /// Current canvas zoom, used to convert screen deltas to canvas space.
  double get canvasScale;

  /// Converts a screen-space drag delta into canvas space.
  ///
  /// A rotated viewport turns a screen delta as well as scaling it, so callers
  /// must not divide by [canvasScale] alone.
  Offset canvasDeltaFromScreen(Offset screenDelta);

  /// Canvas width in pixels.
  double get canvasWidth;

  /// Canvas height in pixels.
  double get canvasHeight;

  /// Repaints the canvas without rebuilding tool options.
  void repaintMainView();

  /// Rebuilds the tool options bar.
  void repaintToolOptions();

  /// Notifies provider listeners.
  void update();

  /// Cancels any live effect preview before the selection changes.
  void cancelEffectPreview();

  /// Drops a queued magic-wand sample.
  void cancelPendingWandRequest();

  /// Queues a magic-wand sample at [position].
  void queueWandRequest({required Offset position, required bool sampleAllLayers});

  /// Applies a new wand tolerance.
  set tolerance(int value);
}
