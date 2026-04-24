// Imports

import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/image_placement_model.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/fill_service.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';

// Exports
export 'package:fpaint/providers/layers_provider.dart';

/// The `AppProvider` class is a `ChangeNotifier` that manages the state of the application,
/// including the canvas, layers, and selection tools. It provides methods for interacting
/// with the canvas, such as clearing the canvas, converting between canvas and screen
/// coordinates, and performing region-based operations like erasing and cutting.
class AppProvider extends ChangeNotifier {
  AppProvider({final AppPreferences? preferences}) : preferences = preferences ?? AppPreferences() {
    this.preferences.addListener(_handlePreferencesChanged);
    _initCanvas();
  }

  /// The application preferences.
  final AppPreferences preferences;

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

  final UndoProvider _undoProvider = UndoProvider();

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

  @override
  void dispose() {
    preferences.removeListener(_handlePreferencesChanged);
    super.dispose();
  }

  void _handlePreferencesChanged() {
    update();
  }

  //=============================================================================
  // All things Canvas

  /// The offset of the canvas.
  Offset canvasOffset = Offset.zero;

  //=============================================================================
  // All things Layers

  /// The layers provider.
  LayersProvider layers = LayersProvider(); // this is a singleton

  /// Records and executes a drawing action to the selected layer.
  void recordExecuteDrawingActionToSelectedLayer({
    required final UserActionDrawing action,
  }) {
    if (selectorModel.isVisible) {
      action.clipPath = selectorModel.path1;
    }

    _undoProvider.executeAction(
      name: action.action.name,
      forward: () => layers.selectedLayer.appendDrawingAction(action),
      backward: () => layers.selectedLayer.undo(),
    );

    layers.update();
  }

  /// Undoes an action.
  void undoAction() {
    _undoProvider.undo();
    update();
  }

  /// Redoes an action.
  void redoAction() {
    _undoProvider.redo();
    update();
  }

  //=============================================================================
  // All things Tools/UserActions

  //-------------------------
  // Selected Tool
  ActionType _selectedAction = ActionType.brush;

  /// Sets the selected action.
  set selectedAction(final ActionType value) {
    _selectedAction = value;

    if (value != ActionType.fill) {
      fillModel.clear();
    }
    update();
  }

  /// Gets the selected action.
  ActionType get selectedAction => _selectedAction;

  //-------------------------
  // Line Weight

  /// Gets the brush size.
  double get brushSize => preferences.brushSize;

  /// Sets the brush size.
  set brushSize(final double value) {
    preferences.setBrushSize(value);
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
    update();
  }

  //-------------------------
  // Brush Color

  /// Gets the brush color.
  Color get brushColor => preferences.brushColor;

  /// Sets the brush color.
  set brushColor(final Color value) {
    preferences.setBrushColor(value);
    update();
  }

  //-------------------------
  // Color for Fill

  /// Gets the fill color.
  Color get fillColor => preferences.fillColor;

  /// Sets the fill color.
  set fillColor(final Color value) {
    preferences.setFillColor(value);
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
    update();
  }

  //-------------------------
  // Fill Widget

  /// The fill model.
  FillModel fillModel = FillModel();

  //-------------------------
  /// The eye drop position for the brush.
  Offset? eyeDropPositionForBrush;

  //-------------------------
  /// The eye drop position for the fill.
  Offset? eyeDropPositionForFill;

  //-------------------------
  // Selector

  /// The selector model.
  SelectorModel selectorModel = SelectorModel();

  /// The image placement model for interactive paste.
  final ImagePlacementModel imagePlacementModel = ImagePlacementModel();

  /// The transform model for perspective/skew operations.
  final TransformModel transformModel = TransformModel();

  /// The selected text object.
  TextObject? selectedTextObject;

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }
}
