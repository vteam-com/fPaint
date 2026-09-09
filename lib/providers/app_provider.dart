// Imports

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/models/brush_grain.dart';
import 'package:fpaint/models/brush_hatch.dart';
import 'package:fpaint/models/effect_brush_model.dart';
import 'package:fpaint/models/effect_preview_model.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/hatch_marks.dart';
import 'package:fpaint/models/hatch_pattern.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/image_placement_model.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/text_tool_state.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/fill_service.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/layer_crop_state.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/pixel_brush_commit.dart';
import 'package:fpaint/providers/selection_effect_preview_state.dart';
import 'package:fpaint/providers/selection_effect_renderer.dart';
import 'package:fpaint/providers/selector_geometry_controller.dart';
import 'package:fpaint/providers/selector_geometry_host.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/providers/wand_selection_manager_cache.dart';
import 'package:fpaint/providers/wand_source_sampler.dart';

// Exports
export 'package:fpaint/providers/layers_provider.dart';

part 'app_provider_canvas.dart';
part 'app_provider_hatch.dart';
part 'app_provider_pixel_brush.dart';
part 'app_provider_selection.dart';
part 'app_provider_selection_commit.dart';
part 'app_provider_selection_crop.dart';
part 'app_provider_selection_cross_layer.dart';
part 'app_provider_selection_effects.dart';
part 'app_provider_tools.dart';
part 'fill_preview_session.dart';
part 'pixel_brush_session.dart';
part 'transform_session.dart';
part 'wand_selection_manager.dart';
part 'wand_selection_request.dart';

/// The `AppProvider` class is a `ChangeNotifier` that manages the state of the application,
/// including the canvas, layers, and selection tools. It provides methods for interacting
/// with the canvas, such as clearing the canvas, converting between canvas and screen
/// coordinates, and performing region-based operations like erasing and cutting.
class AppProvider extends ChangeNotifier implements SelectorGeometryHost {
  AppProvider({
    AppPreferences? preferences,
    LayersProvider? layersProvider,
    UndoProvider? undoProvider,
  }) : preferences = preferences ?? AppPreferences(),
       layers = layersProvider ?? LayersProvider(),
       _undoProvider = undoProvider ?? UndoProvider() {
    this.preferences.addListener(_handlePreferencesChanged);
    layers.layerListStructureListenable.addListener(_handleLayerStructureChanged);
    _initCanvas();
    // Build the grain ("pencil") brush texture ahead of first use. Fire-and-forget
    // with no completion callback: it populates a shared singleton tile, and must
    // not touch this provider afterwards (the future can outlive it — e.g. across
    // tests — and notifying a disposed ChangeNotifier throws).
    unawaited(BrushGrain.instance.prewarm());
    this._prewarmHatchTiles();
  }

  /// The application preferences.
  final AppPreferences preferences;

  final ChangeNotifier _mainViewRepaintNotifier = ChangeNotifier();
  final ChangeNotifier _hudOverlayNotifier = ChangeNotifier();
  final ChangeNotifier _layerModifyModeNotifier = ChangeNotifier();
  final ChangeNotifier _toolOptionsNotifier = ChangeNotifier();
  final ChangeNotifier _viewportRepaintNotifier = ChangeNotifier();
  final ChangeNotifier _selectedActionNotifier = ChangeNotifier();
  Timer? _brushSizePreviewTimer;
  double? _brushSizePreviewSize;
  Offset? _brushSizePreviewPosition;

  // Live Edge Detection tolerance HUD: the value (raw 1–100) and main-view
  // anchor shown while dragging the wand tolerance. Null when not dragging.
  bool _isViewportRotationFeedbackVisible = false;
  int? _wandToleranceHudTolerance;
  Offset? _wandToleranceHudPosition;

  // Live smudge/blur gesture marquee: the in-progress stroke's sampled points
  // (canvas space) and brush size. The effect itself is rendered once on
  // pointer-up; during the drag we only show this swept-band outline so the
  // gesture stays responsive without any per-move rasterization.
  List<Offset>? _pixelBrushGesturePoints;
  double _pixelBrushGestureSize = 0.0;

  /// Whether the pointer-up smudge/blur commit is running. Drives the processing
  /// shimmer over the affected region while the (async) commit generates the
  /// image, then clears with the gesture.
  bool _isPixelBrushCommitting = false;

  void _initCanvas() {
    layers.clear();
    layers.size = layers.size;
    layers.addWhiteBackgroundLayer();
    layers.selectedLayerIndex = 0;
    canvasOffset = Offset.zero;
    layers.scale = 1;
    layers.rotation = 0;
  }

  /// Preferred app locale, or null to follow system locale.
  Locale? get preferredLocale => preferences.preferredLocale;

  /// Preferred app language code, or null to follow system locale.
  String? get languageCode => preferences.languageCode;

  /// Sets the preferred app language code and notifies listeners.
  Future<void> setLanguageCode(String? value) async {
    await preferences.setLanguageCode(value);
    update();
  }

  final UndoProvider _undoProvider;

  /// Gets the undo provider.
  UndoProvider get undoProvider => _undoProvider;

  final FillService _fillService = FillService();

  /// Gets the fill service.
  FillService get fillService => _fillService;

  /// Gets the [AppProvider] instance from the provided [BuildContext].
  ///
  /// If [listen] is true, the returned [AppProvider] instance will notify listeners
  /// when its state changes. Otherwise, the returned instance will not notify
  /// listeners.
  static AppProvider of(
    BuildContext context, {
    bool listen = false,
  }) => InheritedControllerScope.of<AppProvider>(context, listen: listen);

  /// Listenable used to repaint the main canvas and overlay surface only.
  Listenable get mainViewRepaintListenable => _mainViewRepaintNotifier;

  /// Listenable used to repaint only the lightweight gesture HUD overlays
  /// (brush-size ring, smudge marquee, tolerance HUDs). These update at
  /// pointer-move frequency, so they get their own channel instead of
  /// rebuilding the entire main-view overlay stack per input sample.
  Listenable get hudOverlayRepaintListenable => _hudOverlayNotifier;

  /// Listenable used to rebuild tool-option affordance without waking the full app shell.
  Listenable get toolOptionsRepaintListenable => _toolOptionsNotifier;

  /// Listenable used to rebuild side-panel mode chrome only when layer-modify mode changes.
  Listenable get layerModifyModeListenable => _layerModifyModeNotifier;

  /// Listenable used to repaint viewport-driven UI such as zoom and pan affordance.
  Listenable get viewportRepaintListenable => _viewportRepaintNotifier;

  /// Listenable used to rebuild tool-selection affordance only when the tool changes.
  Listenable get selectedActionRepaintListenable => _selectedActionNotifier;

  late final Listenable _mainViewCompositeListenable = Listenable.merge(<Listenable>[
    this,
    viewportRepaintListenable,
    mainViewRepaintListenable,
  ]);

  /// Stable merged listenable for the main view (app state + viewport + main-view repaints).
  ///
  /// Built once so widgets do not allocate a fresh `Listenable.merge` and
  /// re-subscribe on every rebuild, which would add per-frame churn while drawing.
  Listenable get mainViewCompositeListenable => _mainViewCompositeListenable;

  late final Listenable _toolbarActionsListenable = Listenable.merge(<Listenable>[
    _viewportRepaintNotifier,
    this,
    _undoProvider,
  ]);

  /// Stable merged listenable for the top toolbar actions (viewport + app state + undo).
  Listenable get toolbarActionsListenable => _toolbarActionsListenable;

  /// Gets whether layer replacement modify mode is active.
  bool get isLayerModifyMode => transformSession.isLayerModifyMode;

  @override
  void dispose() {
    preferences.removeListener(_handlePreferencesChanged);
    layers.layerListStructureListenable.removeListener(_handleLayerStructureChanged);
    _brushSizePreviewTimer?.cancel();
    _mainViewRepaintNotifier.dispose();
    _hudOverlayNotifier.dispose();
    _layerModifyModeNotifier.dispose();
    _toolOptionsNotifier.dispose();
    _viewportRepaintNotifier.dispose();
    _selectedActionNotifier.dispose();
    super.dispose();
  }

  void _handlePreferencesChanged() {
    update();
  }

  /// Layer-list structural changes (document load/new, add/remove/reorder)
  /// orphan any in-flight pixel-brush commit (its captured layer index may now
  /// point at a different layer) and the smudge source cache (its bytes came
  /// from the old stack, and the count-based signature carries no document
  /// identity), so both are dropped.
  void _handleLayerStructureChanged() {
    pixelBrushSession.clearStroke();
    pixelBrushSession.clearSourceCache();
  }

  /// Rebuilds the main canvas and overlay surface without notifying the full app shell.
  @override
  void repaintMainView() {
    _mainViewRepaintNotifier.notifyListeners();
  }

  /// Rebuilds only the gesture HUD overlays (see [hudOverlayRepaintListenable]).
  void repaintHudOverlay() {
    _hudOverlayNotifier.notifyListeners();
  }

  /// Rebuilds tool-option UI without notifying the full app shell.
  @override
  void repaintToolOptions() {
    _toolOptionsNotifier.notifyListeners();
  }

  /// Rebuilds side-panel mode chrome without notifying the full app shell.
  void repaintLayerModifyMode() {
    _layerModifyModeNotifier.notifyListeners();
  }

  /// Rebuilds side-panel mode chrome only when layer-modify mode toggles.
  void notifyLayerModifyModeChanged({required bool wasActive}) {
    if (wasActive != isLayerModifyMode) {
      repaintLayerModifyMode();
    }
  }

  /// Rebuilds viewport-dependent UI without notifying the full app shell.
  void repaintViewport() {
    _viewportRepaintNotifier.notifyListeners();
  }

  //=============================================================================
  // All things Canvas

  /// The offset of the canvas.
  Offset canvasOffset = Offset.zero;

  /// Memoized [AppProviderCanvas.viewportTransform], invalidated by comparing
  /// the viewport fields rather than by every mutation site remembering to
  /// clear it.
  @visibleForTesting
  ViewportTransform? cachedViewportTransform;

  //=============================================================================
  // All things Layers

  /// The layers provider.
  final LayersProvider layers;

  /// Gets whether the currently selected layer is locked against edits.
  bool get isSelectedLayerLocked => layers.selectedLayer.isLocked;

  /// Records and executes a drawing action to the selected layer.
  bool recordExecuteDrawingActionToSelectedLayer({
    required UserActionDrawing action,
  }) {
    // A stroke landing while an async undo/redo replay (canvas rotate/flip) is
    // still re-rasterizing would clear the redo stack — disposing the very
    // record being replayed — and interleave mutations; drop it instead.
    if (isSelectedLayerLocked || _undoProvider.isReplaying) {
      return false;
    }

    if (selectorModel.isVisible) {
      action.clipPath = selectorModel.path1;
    }

    _undoProvider.executeAction(
      name: action.action.name,
      forward: () => layers.selectedLayer.appendDrawingAction(action),
      backward: () => layers.selectedLayer.undo(),
    );

    layers.update();
    return true;
  }

  /// Undoes an action.
  ///
  /// Awaits the replay so an asynchronous record (canvas rotate/flip) is fully
  /// reverted before dependent UI updates run.
  Future<void> undoAction() async {
    // Finalize any live gradient-fill session first so the transient preview
    // (which is not on the undo stack) never participates in history.
    if (isGradientPreviewActive) {
      applyGradientPreview();
    }
    // A pixel-brush commit still rendering must not land after this undo and
    // resurrect the state the user just reverted; drop the in-flight stroke.
    pixelBrushSession.clearStroke();
    await _undoProvider.undo();
    layers.update();
    update();
  }

  /// Redoes an action; see [undoAction] for the async replay contract.
  Future<void> redoAction() async {
    if (isGradientPreviewActive) {
      applyGradientPreview();
    }
    pixelBrushSession.clearStroke();
    await _undoProvider.redo();
    layers.update();
    update();
  }

  //=============================================================================
  // All things Tools/UserActions

  //-------------------------
  // Selected Tool
  ActionType _selectedAction = ActionType.brush;
  ActionType _lastNonSelectorAction = ActionType.brush;

  /// Activates the selector action while remembering the previous non-selector tool.
  void activateSelectionAction() {
    selectedAction = ActionType.selector;
  }

  /// Clears the current selection UI state and returns to the previous tool.
  void clearSelectionAndRestorePreviousTool() {
    selectorModel.clear();
    selectedAction = _lastNonSelectorAction;
  }

  /// Sets the selected action.
  set selectedAction(ActionType value) {
    final bool selectedActionChanged = value != _selectedAction;

    // Picking any tool cancels an armed paint-mode effect brush, so only one
    // gesture tool is ever active — a stroke is never ambiguous.
    final bool wasEffectBrushArmed = effectBrushModel.effect != null;
    if (wasEffectBrushArmed) {
      effectBrushModel.disarm();
    }

    // Switching tools exits eyedropper mode so pointer interactions follow the new tool.
    if (selectedActionChanged) {
      isEyeDropShortcutActive = false;
      eyeDropPositionForBrush = null;
      eyeDropPositionForFill = null;
    }

    if (value != ActionType.selector) {
      _lastNonSelectorAction = value;
    }

    _selectedAction = value;

    if (value != ActionType.selector && effectPreviewModel.isVisible) {
      effectPreviewModel.clear();
      effectPreviewRenderVersion++;
    }

    if (value != ActionType.fill) {
      // Leaving the fill tool finalizes any live gradient-fill session (implicit
      // Apply — commit exactly one undo entry and clear), otherwise just drop
      // any lingering fill config.
      if (isGradientPreviewActive) {
        applyGradientPreview();
      } else {
        fillModel.clear();
      }
    }

    if (value != ActionType.selector) {
      wandSelection.reset();
    }

    if (value != ActionType.smudge && value != ActionType.blurBrush) {
      // Leaving the pixel-brush tools frees the smudge source cache (a large
      // CPU buffer) — it is rebuilt on the next stroke's first commit.
      pixelBrushSession.clearSourceCache();
    }

    if (value == ActionType.fill) {
      // Start the GPU readback before the first canvas tap.
      unawaited(getSelectedLayerFillImageData(sampleAllLayers: false));
    }

    if (selectedActionChanged || wasEffectBrushArmed) {
      _selectedActionNotifier.notifyListeners();
      repaintToolOptions();
    }

    update();
  }

  /// Gets the selected action.
  ActionType get selectedAction => _selectedAction;

  //-------------------------
  // Line Weight

  /// Gets the brush size.
  double get brushSize => preferences.brushSize;

  /// Gets whether the live brush-size preview overlay is visible.
  bool get isBrushSizePreviewVisible => _brushSizePreviewSize != null;

  /// Gets the current live brush-size preview diameter in canvas units.
  double? get brushSizePreviewSize => _brushSizePreviewSize;

  /// Gets the current live brush-size preview position in main-view space.
  Offset? get brushSizePreviewPosition => _brushSizePreviewPosition;

  /// Gets an inverse of the active brush color for preview visibility.
  Color get brushSizePreviewColor => brushColor;

  /// Whether an in-progress smudge/blur gesture marquee should be drawn.
  bool get isPixelBrushGestureVisible => _pixelBrushGesturePoints != null;

  /// The in-progress smudge/blur gesture points, in canvas space.
  List<Offset>? get pixelBrushGesturePoints => _pixelBrushGesturePoints;

  /// The brush size (canvas units) of the in-progress smudge/blur gesture.
  double get pixelBrushGestureSize => _pixelBrushGestureSize;

  /// Whether the pointer-up smudge/blur commit is currently generating the
  /// image, so the main view should show the processing shimmer.
  bool get isPixelBrushCommitting => _isPixelBrushCommitting;

  /// Marks the smudge/blur commit as running ([committing] true) or finished,
  /// refreshing the overlay so the processing shimmer appears/clears. No-op when
  /// the state is unchanged.
  void setPixelBrushCommitting({required bool committing}) {
    if (_isPixelBrushCommitting == committing) {
      return;
    }
    _isPixelBrushCommitting = committing;
    repaintHudOverlay();
  }

  /// Publishes the in-progress smudge/blur gesture so the main view can draw its
  /// swept-band marquee. Snapshots [points] so later mutation of the stroke list
  /// can't tear a frame mid-paint.
  void showPixelBrushGesture({
    required List<Offset> points,
    required double size,
  }) {
    _pixelBrushGesturePoints = List<Offset>.of(points);
    _pixelBrushGestureSize = size;
    repaintHudOverlay();
  }

  /// Clears the smudge/blur gesture marquee and processing state (on commit or
  /// abandon).
  void clearPixelBrushGesture() {
    if (_pixelBrushGesturePoints == null && !_isPixelBrushCommitting) {
      return;
    }
    _pixelBrushGesturePoints = null;
    _isPixelBrushCommitting = false;
    repaintHudOverlay();
  }

  /// Sets the brush size.
  set brushSize(double value) {
    preferences.setBrushSize(value);
    _showBrushSizePreview(value);
    repaintToolOptions();
    update();
  }

  void _showBrushSizePreview(double value) {
    _brushSizePreviewTimer?.cancel();
    _brushSizePreviewSize = value;
    _brushSizePreviewPosition = null;
    repaintHudOverlay();
    _brushSizePreviewTimer = Timer(AppDefaults.brushSizePreviewDuration, _hideBrushSizePreview);
  }

  /// Shows the brush-size preview at the current pointer position while the user draws.
  void showDrawingToolPreviewAt({
    required double size,
    required Offset position,
  }) {
    _brushSizePreviewTimer?.cancel();
    _brushSizePreviewSize = size;
    _brushSizePreviewPosition = position;
    repaintHudOverlay();
  }

  void _hideBrushSizePreview() {
    if (_brushSizePreviewSize == null) {
      return;
    }
    _brushSizePreviewTimer?.cancel();
    _brushSizePreviewSize = null;
    _brushSizePreviewPosition = null;
    repaintHudOverlay();
  }

  /// Hides any active drawing-time brush-size preview immediately.
  void hideDrawingToolPreview() {
    _hideBrushSizePreview();
  }

  /// Whether the live Edge Detection tolerance HUD should be shown.
  bool get isWandToleranceHudVisible => _wandToleranceHudTolerance != null;

  /// The tolerance shown in the live wand HUD (raw 1–100, read as a percentage).
  int? get wandToleranceHudTolerance => _wandToleranceHudTolerance;

  /// The main-view-space position the wand HUD is anchored to.
  Offset? get wandToleranceHudPosition => _wandToleranceHudPosition;

  /// Shows or updates the live Edge Detection tolerance HUD at [position].
  void showWandToleranceHud({required int tolerance, required Offset position}) {
    _wandToleranceHudTolerance = tolerance;
    _wandToleranceHudPosition = position;
    repaintHudOverlay();
  }

  /// Hides the live Edge Detection tolerance HUD.
  void hideWandToleranceHud() {
    if (_wandToleranceHudTolerance == null) {
      return;
    }
    _wandToleranceHudTolerance = null;
    _wandToleranceHudPosition = null;
    repaintHudOverlay();
  }

  /// Gets the active pixel-brush intensity for the selected tool.
  double get brushIntensity {
    switch (_selectedAction) {
      case ActionType.smudge:
        return preferences.smudgeIntensity;
      case ActionType.blurBrush:
        return preferences.blurBrushIntensity;
      default:
        return AppInteraction.pixelBrushDefaultIntensity;
    }
  }

  /// Sets the active pixel-brush intensity for the selected tool.
  set brushIntensity(double value) {
    switch (_selectedAction) {
      case ActionType.smudge:
        preferences.setSmudgeIntensity(value);
        break;
      case ActionType.blurBrush:
        preferences.setBlurBrushIntensity(value);
        break;
      default:
        return;
    }
    repaintToolOptions();
    update();
  }

  //-------------------------
  // Brush Style
  BrushStyle _brushStyle = BrushStyle.solid;

  /// Gets the brush style.
  BrushStyle get brushStyle => _brushStyle;

  /// Sets the brush style.
  set brushStyle(BrushStyle value) {
    _brushStyle = value;
    if (value.isHatch) {
      this._prewarmHatchTiles();
    }
    repaintToolOptions();
    update();
  }

  //-------------------------
  // Hatch pattern (shared by the hatch brush styles and the hatch fill); the
  // accessors live in the AppProviderHatch extension (app_provider_hatch.dart).
  HatchPattern _hatchPattern = const HatchPattern();
  HatchMarks _hatchMarks = const HatchMarks();

  //-------------------------
  // Brush Color

  /// Gets the brush color.
  Color get brushColor => preferences.brushColor;

  /// Sets the brush color.
  set brushColor(Color value) {
    preferences.setBrushColor(value);
    layers.recentColors.record(value);
    repaintToolOptions();
    update();
  }

  //-------------------------
  // Color for Fill

  /// Gets the fill color.
  Color get fillColor => preferences.fillColor;

  /// Sets the fill color.
  set fillColor(Color value) {
    preferences.setFillColor(value);
    layers.recentColors.record(value);
    repaintToolOptions();
    update();
  }

  //-------------------------
  // Tolerance
  int _tolerance = AppDefaults.tolerance;

  /// Gets the tolerance.
  int get tolerance => _tolerance;

  /// Sets the tolerance.
  @override
  set tolerance(int value) {
    _tolerance = max(1, min(AppLimits.percentMax, value));
    repaintToolOptions();
    update();
  }

  //-------------------------
  // Fill Widget

  /// Owns the live paint-bucket fill preview session (fill config, held
  /// preview action, render version). See [FillPreviewSession].
  final FillPreviewSession fillPreviewSession = FillPreviewSession();

  /// The fill model.
  FillModel get fillModel => fillPreviewSession.fillModel;

  /// The **held** fill preview action; owned by [FillPreviewSession]. See
  /// `updateSolidFillPreview` / `updateGradientPreview` / `commitFillPreview`.
  UserActionDrawing? get fillPreviewAction => fillPreviewSession.heldAction;

  /// Whether a live gradient-fill preview session is active. Only
  /// [FillModel.isVisible] gradient sessions set this; solid fills preview only
  /// during the pointer press and commit on release.
  bool get isGradientPreviewActive => fillPreviewSession.isGradientPreviewActive;

  int? _fillTolerancePreview;

  /// The tolerance shown in the top "Fill Tolerance" bar while a paint-bucket
  /// tolerance drag is active, or null when the bar is hidden.
  int? get fillTolerancePreview => _fillTolerancePreview;

  /// Shows/updates the top "Fill Tolerance" bar with [value].
  void showFillTolerancePreview(int value) {
    if (_fillTolerancePreview == value) {
      return;
    }
    _fillTolerancePreview = value;
    repaintHudOverlay();
  }

  /// Hides the top "Fill Tolerance" bar.
  void hideFillTolerancePreview() {
    if (_fillTolerancePreview == null) {
      return;
    }
    _fillTolerancePreview = null;
    repaintHudOverlay();
  }

  Offset? _tolerancePointerAnchor;

  /// Screen-space start point of an active horizontal tolerance drag (wand or
  /// paint bucket), or null when no such drag is active. While set, the OS
  /// cursor is hidden and a fixed marker is pinned here, so the tolerance scrub
  /// reads as adjusting a value in place rather than dragging across the canvas.
  Offset? get tolerancePointerAnchor => _tolerancePointerAnchor;

  /// Whether a horizontal tolerance drag is holding the pointer at its start.
  bool get isTolerancePointerLocked => _tolerancePointerAnchor != null;

  /// Pins the tolerance drag to [screenAnchor]: hides the cursor and shows the
  /// fixed anchor marker.
  void beginTolerancePointerLock(Offset screenAnchor) {
    _tolerancePointerAnchor = screenAnchor;
    repaintToolOptions(); // rebuild the cursor MouseRegion to hide the cursor
    repaintHudOverlay(); // draw the fixed anchor marker
  }

  /// Releases the tolerance pointer lock, restoring the cursor.
  void endTolerancePointerLock() {
    if (_tolerancePointerAnchor == null) {
      return;
    }
    _tolerancePointerAnchor = null;
    repaintToolOptions();
    repaintHudOverlay();
  }

  /// Commits the held fill preview action (if any) as exactly one undoable
  /// action, then clears it. What is committed is exactly what the overlay shows
  /// (WYSIWYG); if nothing has been previewed yet, nothing is committed. Stays on
  /// the base class so the tool-switch setter, undo/redo, and the gesture handler
  /// can finalize without depending on the tools extension.
  void commitFillPreview() {
    final UserActionDrawing? rendered = fillPreviewSession.takeHeldAction();
    if (rendered != null) {
      recordExecuteDrawingActionToSelectedLayer(action: rendered);
    }
    repaintMainView();
  }

  /// Drops the held fill preview without recording anything.
  void clearFillPreview() {
    fillPreviewSession.clearHeldAction();
    repaintMainView();
  }

  /// Applies the live gradient-fill preview session, committing its held action
  /// and ending the session. Safe to call with no active session.
  void applyGradientPreview() {
    if (!fillModel.isVisible) {
      return;
    }
    commitFillPreview();
    fillModel.clear();
    update();
  }

  /// Discards the live gradient-fill preview session without recording any undo
  /// entry. Safe to call with no active session.
  void cancelGradientPreview() {
    if (!fillModel.isVisible && fillPreviewAction == null) {
      return;
    }
    clearFillPreview();
    fillModel.clear();
    update();
  }

  /// The shared style state for the text tool.
  late final TextToolState textToolState = TextToolState(
    size: preferences.brushSize,
    color: preferences.brushColor,
  );

  /// Applies a complete text-tool style snapshot and notifies listeners.
  void applyTextToolState(TextToolState value) {
    textToolState.size = value.size;
    textToolState.color = value.color;
    textToolState.fontWeight = value.fontWeight;
    textToolState.fontStyle = value.fontStyle;
    textToolState.textAlign = value.textAlign;
    repaintToolOptions();
    update();
  }

  /// Copies the style of [textObject] into the shared text tool state.
  void adoptTextToolStateFromObject(TextObject textObject) {
    applyTextToolState(TextToolState.fromTextObject(textObject));
  }

  //-------------------------
  bool isEyeDropShortcutActive = false;

  Offset? _lastPointerPosition;

  /// Gets the last known main-view pointer position.
  // ignore: unnecessary_getters_setters
  Offset? get lastPointerPosition => _lastPointerPosition;

  /// Sets the last known main-view pointer position.
  set lastPointerPosition(Offset? value) {
    _lastPointerPosition = value;
  }

  /// Activates the eyedropper via keyboard shortcut (Alt / Option).
  void activateEyeDropShortcut({Offset? position}) {
    isEyeDropShortcutActive = true;
    final Offset initialPos = position ?? _lastPointerPosition ?? canvasCenter;
    if (_selectedAction == ActionType.fill) {
      eyeDropPositionForFill = initialPos;
    } else {
      eyeDropPositionForBrush = initialPos;
    }
  }

  /// Deactivates the keyboard shortcut eyedropper.
  void deactivateEyeDropShortcut() {
    isEyeDropShortcutActive = false;
    eyeDropPositionForBrush = null;
    eyeDropPositionForFill = null;
  }

  //-------------------------
  Offset? _eyeDropPositionForBrush;

  /// The eye drop position for the brush.
  Offset? get eyeDropPositionForBrush => _eyeDropPositionForBrush;

  /// Sets the eye drop position for the brush.
  set eyeDropPositionForBrush(Offset? value) {
    final bool activeChanged = (_eyeDropPositionForBrush == null) != (value == null);
    final bool positionChanged = _eyeDropPositionForBrush != value;
    _eyeDropPositionForBrush = value;
    if (activeChanged) {
      repaintToolOptions();
    }
    if (positionChanged) {
      repaintMainView();
    }
  }

  //-------------------------
  /// The eye drop position for the fill.
  Offset? _eyeDropPositionForFill;

  /// Gets the eye drop position for the fill.
  Offset? get eyeDropPositionForFill => _eyeDropPositionForFill;

  /// Sets the eye drop position for the fill.
  set eyeDropPositionForFill(Offset? value) {
    final bool activeChanged = (_eyeDropPositionForFill == null) != (value == null);
    final bool positionChanged = _eyeDropPositionForFill != value;
    _eyeDropPositionForFill = value;
    if (activeChanged) {
      repaintToolOptions();
    }
    if (positionChanged) {
      repaintMainView();
    }
  }

  //-------------------------
  // Selector

  /// The selector model.
  @override
  SelectorModel selectorModel = SelectorModel();

  /// Shapes the active selection (create, move, scale, resize, rotate).
  ///
  /// Composed rather than mixed in, so selection geometry stays testable
  /// against [SelectorGeometryHost] without building the whole provider.
  late final SelectorGeometryController selectorGeometry = SelectorGeometryController(this);

  /// Current canvas zoom. Part of [SelectorGeometryHost].
  @override
  double get canvasScale => layers.scale;

  /// Current viewport rotation in radians, clockwise-positive.
  double get canvasRotation => layers.rotation;

  /// Converts a screen-space drag delta into canvas space.
  /// Part of [SelectorGeometryHost].
  @override
  Offset canvasDeltaFromScreen(Offset screenDelta) => deltaToCanvas(screenDelta);

  /// Canvas width in pixels. Part of [SelectorGeometryHost].
  @override
  double get canvasWidth => layers.width;

  /// Canvas height in pixels. Part of [SelectorGeometryHost].
  @override
  double get canvasHeight => layers.height;

  /// Cancels any live effect preview, discarding the pending result.
  ///
  /// Declared on the class (not the effects extension) because
  /// [SelectorGeometryHost] requires it: selection changes must drop a preview
  /// that was captured against the old region.
  @override
  void cancelEffectPreview() {
    if (!effectPreviewModel.isVisible) {
      return;
    }

    effectPreviewModel.clear();
    effectPreviewRenderVersion++;
    repaintToolOptions();
    update();
  }

  /// Drops a queued magic-wand sample. Part of [SelectorGeometryHost].
  @override
  void cancelPendingWandRequest() => wandSelection.cancelPendingRequest();

  /// Queues a magic-wand sample. Part of [SelectorGeometryHost].
  @override
  void queueWandRequest({required Offset position, required bool sampleAllLayers}) {
    wandSelection.queueRequest(position: position, sampleAllLayers: sampleAllLayers);
    unawaited(_processPendingWandSelectionRequests());
  }

  /// Owns the floating transform/placement session state (transform overlay,
  /// prepared image placement, cross-layer lift). See [TransformSession].
  final TransformSession transformSession = TransformSession();

  /// The prepared image placement state used by duplicate, paste, and layer modify sessions.
  ImagePlacementModel get imagePlacementModel => transformSession.imagePlacementModel;

  /// The transform model for perspective/skew operations.
  TransformModel get transformModel => transformSession.transformModel;

  /// Whether an interactive transform overlay is currently active.
  bool get hasActiveTransformOverlay => transformModel.isVisible;

  /// The effect preview model for live selection-effect intensity updates.
  final EffectPreviewModel effectPreviewModel = EffectPreviewModel();

  /// Pure image pipeline behind effect preview and commit.
  ///
  /// Composed rather than inherited so the effect maths stays testable on its
  /// own and this provider keeps only the session lifecycle.
  final SelectionEffectRenderer effectRenderer = const SelectionEffectRenderer();

  /// The paint-mode state for brushing an Adjust effect onto the canvas.
  final EffectBrushModel effectBrushModel = EffectBrushModel();

  /// Monotonic token that invalidates stale async effect preview renders.
  int effectPreviewRenderVersion = 0;

  /// Owns the magic-wand selection request queue and rasterized source cache.
  final WandSelectionManager wandSelection = WandSelectionManager();

  /// Rasterizes the pixels the wand and paint bucket sample from.
  ///
  /// Composed over [wandSelection]'s cache so sampling stays independent of the
  /// selection state it eventually feeds.
  late final WandSourceSampler wandSourceSampler = WandSourceSampler(wandSelection);

  /// Owns the in-progress pixel-brush/effect stroke and smudge source cache.
  final PixelBrushStrokeSession pixelBrushSession = PixelBrushStrokeSession();

  /// The selected text object.
  TextObject? selectedTextObject;

  /// Sets the active fill mode and rebuilds tool options.
  void setFillMode(FillMode value) {
    fillModel.mode = value;
    repaintToolOptions();
    update();
  }

  /// Sets whether flood fill should render as a halftone pattern.
  void setFillHalftoneEnabled(bool value) {
    fillModel.halftoneEnabled = value;
    repaintToolOptions();
    update();
  }

  /// Sets the maximum halftone dot size percentage.
  void setFillHalftoneMaxDotSizePercent(int value) {
    fillModel.halftoneMaxDotSizePercent = value;
    repaintToolOptions();
    update();
  }

  /// Sets the active selector mode and rebuilds tool options.
  void setSelectorMode(SelectorMode value) {
    selectorModel.mode = value;
    repaintToolOptions();
    update();
  }

  /// Whether the Edge Detection (magic wand) selector is the active tool.
  ///
  /// Gates wand-only affordances such as the canvas tolerance control and the
  /// crosshair cursor.
  bool get isWandSelectionActive => selectedAction == ActionType.selector && selectorModel.mode == SelectorMode.wand;

  /// Sets the active selector math mode and rebuilds tool options.
  void setSelectorMath(SelectorMath value) {
    selectorModel.math = value;
    repaintToolOptions();
    update();
  }

  /// Sets the shared text-tool font size.
  void setTextToolSize(double value) {
    textToolState.size = value;
    repaintToolOptions();
    update();
  }

  /// Sets the shared text-tool color.
  void setTextToolColor(Color value) {
    textToolState.color = value;
    repaintToolOptions();
    update();
  }

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  @override
  void update() {
    notifyListeners();
  }
}
