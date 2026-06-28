// Imports

import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/effect_preview_model.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/image_placement_model.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/text_tool_state.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/fill_service.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/providers/wand_selection_manager.dart';

// Exports
export 'package:fpaint/providers/layers_provider.dart';

/// The `AppProvider` class is a `ChangeNotifier` that manages the state of the application,
/// including the canvas, layers, and selection tools. It provides methods for interacting
/// with the canvas, such as clearing the canvas, converting between canvas and screen
/// coordinates, and performing region-based operations like erasing and cutting.
class AppProvider extends ChangeNotifier {
  AppProvider({
    final AppPreferences? preferences,
    final LayersProvider? layersProvider,
    final UndoProvider? undoProvider,
  }) : preferences = preferences ?? AppPreferences(),
       layers = layersProvider ?? LayersProvider(),
       _undoProvider = undoProvider ?? UndoProvider() {
    this.preferences.addListener(_handlePreferencesChanged);
    _initCanvas();
  }

  /// The application preferences.
  final AppPreferences preferences;

  final ChangeNotifier _mainViewRepaintNotifier = ChangeNotifier();
  final ChangeNotifier _layerModifyModeNotifier = ChangeNotifier();
  final ChangeNotifier _toolOptionsNotifier = ChangeNotifier();
  final ChangeNotifier _viewportRepaintNotifier = ChangeNotifier();
  final ChangeNotifier _selectedActionNotifier = ChangeNotifier();
  Timer? _brushSizePreviewTimer;
  double? _brushSizePreviewSize;
  Offset? _brushSizePreviewPosition;

  void _initCanvas() {
    layers.clear();
    layers.size = layers.size;
    layers.addWhiteBackgroundLayer();
    layers.selectedLayerIndex = 0;
    canvasOffset = Offset.zero;
    layers.scale = 1;
  }

  /// Preferred app locale, or null to follow system locale.
  Locale? get preferredLocale => preferences.preferredLocale;

  /// Preferred app language code, or null to follow system locale.
  String? get languageCode => preferences.languageCode;

  /// Sets the preferred app language code and notifies listeners.
  Future<void> setLanguageCode(final String? value) async {
    await preferences.setLanguageCode(value);
    update();
  }

  final UndoProvider _undoProvider;

  /// Gets the undo provider.
  UndoProvider get undoProvider => _undoProvider;

  final Debouncer _debounceGradientFill = Debouncer();

  /// Gets the gradient fill debouncer.
  Debouncer get debounceGradientFill => _debounceGradientFill;

  final FillService _fillService = FillService();

  /// Gets the fill service.
  FillService get fillService => _fillService;

  /// Gets the [AppProvider] instance from the provided [BuildContext].
  ///
  /// If [listen] is true, the returned [AppProvider] instance will notify listeners
  /// when its state changes. Otherwise, the returned instance will not notify
  /// listeners.
  static AppProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) => Provider.of<AppProvider>(context, listen: listen);

  /// Listenable used to repaint the main canvas and overlay surface only.
  Listenable get mainViewRepaintListenable => _mainViewRepaintNotifier;

  /// Listenable used to rebuild tool-option affordance without waking the full app shell.
  Listenable get toolOptionsRepaintListenable => _toolOptionsNotifier;

  /// Listenable used to rebuild side-panel mode chrome only when layer-modify mode changes.
  Listenable get layerModifyModeListenable => _layerModifyModeNotifier;

  /// Listenable used to repaint viewport-driven UI such as zoom and pan affordance.
  Listenable get viewportRepaintListenable => _viewportRepaintNotifier;

  /// Listenable used to rebuild tool-selection affordance only when the tool changes.
  Listenable get selectedActionRepaintListenable => _selectedActionNotifier;

  /// Gets whether layer replacement modify mode is active.
  bool get isLayerModifyMode =>
      imagePlacementModel.commitMode == ImagePlacementCommitMode.replaceLayer &&
      imagePlacementModel.layerRestoreState != null;

  @override
  void dispose() {
    preferences.removeListener(_handlePreferencesChanged);
    _brushSizePreviewTimer?.cancel();
    _mainViewRepaintNotifier.dispose();
    _layerModifyModeNotifier.dispose();
    _toolOptionsNotifier.dispose();
    _viewportRepaintNotifier.dispose();
    _selectedActionNotifier.dispose();
    super.dispose();
  }

  void _handlePreferencesChanged() {
    update();
  }

  /// Rebuilds the main canvas and overlay surface without notifying the full app shell.
  void repaintMainView() {
    _mainViewRepaintNotifier.notifyListeners();
  }

  /// Rebuilds tool-option UI without notifying the full app shell.
  void repaintToolOptions() {
    _toolOptionsNotifier.notifyListeners();
  }

  /// Rebuilds side-panel mode chrome without notifying the full app shell.
  void repaintLayerModifyMode() {
    _layerModifyModeNotifier.notifyListeners();
  }

  /// Rebuilds side-panel mode chrome only when layer-modify mode toggles.
  void notifyLayerModifyModeChanged({required final bool wasActive}) {
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

  //=============================================================================
  // All things Layers

  /// The layers provider.
  final LayersProvider layers;

  /// Gets whether the currently selected layer is locked against edits.
  bool get isSelectedLayerLocked => layers.selectedLayer.isLocked;

  /// Records and executes a drawing action to the selected layer.
  bool recordExecuteDrawingActionToSelectedLayer({
    required final UserActionDrawing action,
  }) {
    if (isSelectedLayerLocked) {
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
  void undoAction() {
    _undoProvider.undo();
    layers.update();
    update();
  }

  /// Redoes an action.
  void redoAction() {
    _undoProvider.redo();
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
  set selectedAction(final ActionType value) {
    final bool selectedActionChanged = value != _selectedAction;

    // Switching tools exits eyedropper mode so pointer interactions follow the new tool.
    if (selectedActionChanged) {
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
      fillModel.clear();
    }

    if (value != ActionType.selector) {
      wandSelection.reset();
    }

    if (selectedActionChanged) {
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

  /// Sets the brush size.
  set brushSize(final double value) {
    preferences.setBrushSize(value);
    _showBrushSizePreview(value);
    repaintToolOptions();
    update();
  }

  void _showBrushSizePreview(final double value) {
    _brushSizePreviewTimer?.cancel();
    _brushSizePreviewSize = value;
    _brushSizePreviewPosition = null;
    repaintMainView();
    _brushSizePreviewTimer = Timer(AppDefaults.brushSizePreviewDuration, _hideBrushSizePreview);
  }

  /// Shows the brush-size preview at the current pointer position while the user draws.
  void showDrawingToolPreviewAt({
    required final double size,
    required final Offset position,
  }) {
    _brushSizePreviewTimer?.cancel();
    _brushSizePreviewSize = size;
    _brushSizePreviewPosition = position;
    repaintMainView();
  }

  void _hideBrushSizePreview() {
    if (_brushSizePreviewSize == null) {
      return;
    }
    _brushSizePreviewTimer?.cancel();
    _brushSizePreviewSize = null;
    _brushSizePreviewPosition = null;
    repaintMainView();
  }

  /// Hides any active drawing-time brush-size preview immediately.
  void hideDrawingToolPreview() {
    _hideBrushSizePreview();
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
  set brushIntensity(final double value) {
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
  set brushStyle(final BrushStyle value) {
    _brushStyle = value;
    repaintToolOptions();
    update();
  }

  //-------------------------
  // Brush Color

  /// Gets the brush color.
  Color get brushColor => preferences.brushColor;

  /// Sets the brush color.
  set brushColor(final Color value) {
    preferences.setBrushColor(value);
    repaintToolOptions();
    update();
  }

  //-------------------------
  // Color for Fill

  /// Gets the fill color.
  Color get fillColor => preferences.fillColor;

  /// Sets the fill color.
  set fillColor(final Color value) {
    preferences.setFillColor(value);
    repaintToolOptions();
    update();
  }

  //-------------------------
  // Tolerance
  int _tolerance = AppDefaults.tolerance;

  /// Gets the tolerance.
  int get tolerance => _tolerance;

  /// Sets the tolerance.
  set tolerance(final int value) {
    _tolerance = max(1, min(AppLimits.percentMax, value));
    repaintToolOptions();
    update();
  }

  //-------------------------
  // Fill Widget

  /// The fill model.
  FillModel fillModel = FillModel();

  /// The shared style state for the text tool.
  late final TextToolState textToolState = TextToolState(
    size: preferences.brushSize,
    color: preferences.brushColor,
  );

  /// Applies a complete text-tool style snapshot and notifies listeners.
  void applyTextToolState(final TextToolState value) {
    textToolState.size = value.size;
    textToolState.color = value.color;
    textToolState.fontWeight = value.fontWeight;
    textToolState.fontStyle = value.fontStyle;
    textToolState.textAlign = value.textAlign;
    repaintToolOptions();
    update();
  }

  /// Copies the style of [textObject] into the shared text tool state.
  void adoptTextToolStateFromObject(final TextObject textObject) {
    applyTextToolState(TextToolState.fromTextObject(textObject));
  }

  //-------------------------
  Offset? _eyeDropPositionForBrush;

  /// The eye drop position for the brush.
  Offset? get eyeDropPositionForBrush => _eyeDropPositionForBrush;

  /// Sets the eye drop position for the brush.
  set eyeDropPositionForBrush(final Offset? value) {
    final bool activeChanged = (_eyeDropPositionForBrush == null) != (value == null);
    _eyeDropPositionForBrush = value;
    if (activeChanged) {
      repaintToolOptions();
    }
  }

  //-------------------------
  /// The eye drop position for the fill.
  Offset? _eyeDropPositionForFill;

  /// Gets the eye drop position for the fill.
  Offset? get eyeDropPositionForFill => _eyeDropPositionForFill;

  /// Sets the eye drop position for the fill.
  set eyeDropPositionForFill(final Offset? value) {
    final bool activeChanged = (_eyeDropPositionForFill == null) != (value == null);
    _eyeDropPositionForFill = value;
    if (activeChanged) {
      repaintToolOptions();
    }
  }

  //-------------------------
  // Selector

  /// The selector model.
  SelectorModel selectorModel = SelectorModel();

  /// The prepared image placement state used by duplicate, paste, and layer modify sessions.
  final ImagePlacementModel imagePlacementModel = ImagePlacementModel();

  /// The transform model for perspective/skew operations.
  final TransformModel transformModel = TransformModel();

  /// Whether an interactive transform overlay is currently active.
  bool get hasActiveTransformOverlay => transformModel.isVisible;

  /// The effect preview model for live selection-effect intensity updates.
  final EffectPreviewModel effectPreviewModel = EffectPreviewModel();

  /// Monotonic token that invalidates stale async effect preview renders.
  int effectPreviewRenderVersion = 0;

  /// Owns the magic-wand selection request queue and rasterized source cache.
  final WandSelectionManager wandSelection = WandSelectionManager();

  /// The selected text object.
  TextObject? selectedTextObject;

  /// Sets the active fill mode and rebuilds tool options.
  void setFillMode(final FillMode value) {
    fillModel.mode = value;
    repaintToolOptions();
    update();
  }

  /// Sets whether flood fill should render as a halftone pattern.
  void setFillHalftoneEnabled(final bool value) {
    fillModel.halftoneEnabled = value;
    repaintToolOptions();
    update();
  }

  /// Sets the maximum halftone dot size percentage.
  void setFillHalftoneMaxDotSizePercent(final int value) {
    fillModel.halftoneMaxDotSizePercent = value;
    repaintToolOptions();
    update();
  }

  /// Sets the active selector mode and rebuilds tool options.
  void setSelectorMode(final SelectorMode value) {
    selectorModel.mode = value;
    repaintToolOptions();
    update();
  }

  /// Sets the active selector math mode and rebuilds tool options.
  void setSelectorMath(final SelectorMath value) {
    selectorModel.math = value;
    repaintToolOptions();
    update();
  }

  /// Sets the shared text-tool font size.
  void setTextToolSize(final double value) {
    textToolState.size = value;
    repaintToolOptions();
    update();
  }

  /// Sets the shared text-tool color.
  void setTextToolColor(final Color value) {
    textToolState.color = value;
    repaintToolOptions();
    update();
  }

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }
}
