import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/providers/selector_geometry_host.dart';

/// Edits the active selection's geometry: creating it, moving, scaling,
/// resizing and rotating it, and selecting the whole canvas.
///
/// Split out of the selection provider because shaping a selection is a
/// distinct job from acting on one (cut, copy, transform, effects). It holds no
/// state of its own — the selection lives in [SelectorGeometryHost.selectorModel]
/// — so it is a pure behavior collaborator (Single Responsibility).
class SelectorGeometryController {
  const SelectorGeometryController(this._host);

  final SelectorGeometryHost _host;

  SelectorModel get _model => _host.selectorModel;

  /// Distance, in canvas units, within which a click closes a polygon region.
  double get _closeDistance => AppInteraction.selectionHandleSize / _host.canvasScale;

  /// Starts a selector creation at [position].
  ///
  /// Wand mode samples a region; line mode accumulates polygon points; the
  /// remaining modes begin a drag rectangle/lasso.
  void creationStart(Offset position, {bool sampleAllLayers = false}) {
    _host.cancelEffectPreview();
    if (_model.mode == SelectorMode.wand) {
      _model.isDrawing = true;
      _host.queueWandRequest(position: position, sampleAllLayers: sampleAllLayers);
      return;
    }

    if (_model.mode == SelectorMode.line) {
      final bool isClosed = _model.addStraightLineRegionPoint(
        position,
        closeDistance: _closeDistance,
      );
      _model.isDrawing = !isClosed;
      if (isClosed) {
        _model.applyMath();
      }
      _host.repaintToolOptions();
      _host.update();
      return;
    }

    _model.isDrawing = true;
    _model.addP1(position);
    _host.repaintToolOptions();
    _host.update();
  }

  /// Adds an additional point to the in-progress selection.
  void creationAdditionalPoint(Offset position) {
    // Wand commits on pointer-down; straight-line regions commit on clicks.
    if (_model.mode == SelectorMode.wand || _model.mode == SelectorMode.line) {
      return;
    }
    _model.addP2(position);
    _host.repaintMainView();
  }

  /// Updates the rubber-band preview while a polygon region is in progress.
  void creationPreview(Offset position) {
    if (_model.mode != SelectorMode.line || !_model.isDrawing) {
      return;
    }

    _model.updateStraightLineRegionPreview(position, closeDistance: _closeDistance);
    _host.repaintMainView();
  }

  /// Ends the selector creation gesture.
  void creationEnd() {
    if (_model.mode == SelectorMode.wand) {
      _model.isDrawing = false;
      _host.repaintToolOptions();
      _host.update();
      return;
    }

    // A straight-line region stays open until it is explicitly closed.
    if (_model.mode == SelectorMode.line) {
      return;
    }

    _model.isDrawing = false;
    _model.applyMath();
    _host.repaintToolOptions();
    _host.update();
  }

  /// Closes an active straight-line region and commits it.
  ///
  /// Returns whether the region was closed.
  bool creationClosePolygon() {
    if (_model.mode != SelectorMode.line || !_model.isDrawing) {
      return false;
    }

    if (!_model.closeStraightLineRegion()) {
      return false;
    }

    _model.isDrawing = false;
    _model.applyMath();
    _host.repaintToolOptions();
    _host.update();
    return true;
  }

  /// Translates the active selection by [screenDelta], a screen-space offset.
  void translateByScreenDelta(Offset screenDelta) {
    _model.translate(screenDelta / _host.canvasScale);
    _host.repaintMainView();
  }

  /// Scales the active selection uniformly by [factor].
  void scaleUniform(double factor) {
    _model.scaleUniform(factor);
    _host.repaintMainView();
  }

  /// Resizes the active selection by dragging [handle] by [screenDelta].
  void resize(NineGridHandle handle, Offset screenDelta) {
    _model.nindeGridResize(handle, screenDelta / _host.canvasScale);
    _host.repaintMainView();
  }

  /// Rotates the active selection by [angleRadians].
  void rotate(double angleRadians) {
    _model.rotate(angleRadians);
    _host.repaintMainView();
  }

  /// Selects the whole canvas, replacing any active selection.
  void selectAll() {
    _host.cancelEffectPreview();
    _host.cancelPendingWandRequest();
    _model.isVisible = true;
    _model.isDrawing = false;
    _model.path1 = Path()
      ..addRect(
        Rect.fromPoints(Offset.zero, Offset(_host.canvasWidth, _host.canvasHeight)),
      );
    _model.path2 = null;
    _model.points.clear();
    _model.math = SelectorMath.replace;
    _host.repaintToolOptions();
    _host.update();
  }

  /// Maps a horizontal screen drag [screenDx] from the wand sample anchor onto a
  /// tolerance, starting from [startTolerance]. Dragging right loosens (grows)
  /// the selection; dragging left tightens it.
  int wandToleranceForDrag(int startTolerance, double screenDx) {
    final int delta = (screenDx / AppInteraction.wandToleranceDragPixelsPerUnit).round();
    return (startTolerance + delta).clamp(AppMath.one, AppLimits.percentMax);
  }

  /// Re-runs the Edge Detection wand selection at the fixed sample [position]
  /// using [tolerance]. Drives the live "tap to sample, drag to grow/shrink"
  /// gesture — each drag step resamples the same anchor at the new tolerance.
  void wandResampleAt(
    Offset position, {
    required int tolerance,
    required bool sampleAllLayers,
  }) {
    if (_model.mode != SelectorMode.wand) {
      return;
    }
    _host.tolerance = tolerance;
    _model.isDrawing = true;
    _host.queueWandRequest(position: position, sampleAllLayers: sampleAllLayers);
  }
}
