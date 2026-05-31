// Imports
import 'dart:core';

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:provider/provider.dart';

// Exports
export 'package:fpaint/models/canvas_resize.dart';

/// Defines the different modes for the application shell.
enum ShellMode {
  /// The shell is completely hidden.
  hidden,

  /// The shell is in a minimal state, showing only essential elements.
  minimal,

  /// The shell is in a full state, showing all available elements.
  full,
}

/// Manages the state and behavior of the application shell.
///
/// This class is a [ChangeNotifier] that provides access to various properties
/// related to the application shell, such as the current [ShellMode], whether the
/// side panel is expanded, and whether the menu is visible. It also provides
/// methods for updating these properties and notifying listeners of any changes.
class ShellProvider extends ChangeNotifier {
  final ChangeNotifier _mainScreenLayoutNotifier = ChangeNotifier();
  final ChangeNotifier _sidePanelExpandedNotifier = ChangeNotifier();

  /// Retrieves the [ShellProvider] instance from the given [BuildContext].
  ///
  /// The [listen] parameter determines whether the widget should rebuild when the
  /// [ShellProvider]'s state changes.
  static ShellProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) => Provider.of<ShellProvider>(context, listen: listen);

  /// Returns [ShellProvider] when found in the tree, otherwise null.
  static ShellProvider? maybeOf(
    final BuildContext context, {
    final bool listen = false,
  }) {
    try {
      return Provider.of<ShellProvider>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }

  /// The name of the loaded file.
  String loadedFileName = '';

  bool _deviceSizeSmall = false;

  /// Whether the device size is small.
  bool get deviceSizeSmall => _deviceSizeSmall;

  /// Sets whether the device size is small and rebuilds shell layout when needed.
  set deviceSizeSmall(final bool value) {
    if (_deviceSizeSmall == value) {
      return;
    }
    _deviceSizeSmall = value;
    _mainScreenLayoutNotifier.notifyListeners();
    update();
  }

  /// Synchronizes the viewport size class without notifying listeners.
  void syncDeviceSizeSmall(final bool value) {
    _deviceSizeSmall = value;
  }

  /// The canvas auto placement setting.
  CanvasAutoPlacement canvasPlacement = CanvasAutoPlacement.fit;

  /// Requests the canvas to auto-fit within the viewport on the next frame.
  ///
  /// Centralizes the pattern of setting [canvasPlacement] to
  /// [CanvasAutoPlacement.fit] and notifying listeners so the
  /// [MainView] layout builder re-centres / re-scales the canvas.
  void requestCanvasFit() {
    canvasPlacement = CanvasAutoPlacement.fit;
    update();
  }

  InteractionInputModality _interactionInputModality = InteractionInputModality.mouse;

  /// Current dominant input modality used to scale interactive controls.
  InteractionInputModality get interactionInputModality => _interactionInputModality;

  /// Sets [interactionInputModality] and notifies listeners only on change.
  set interactionInputModality(final InteractionInputModality value) {
    if (_interactionInputModality == value) {
      return;
    }
    _interactionInputModality = value;
    update();
  }

  /// Resolved interaction layout profile for the active [interactionInputModality].
  InteractionLayoutProfile get interactionLayoutProfile =>
      AppInteractionProfiles.forModality(_interactionInputModality);

  //=============================================================================
  // Shell
  ShellMode _shellMode = ShellMode.full;

  /// The current shell mode.
  ShellMode get shellMode => _shellMode;

  /// Listenable used by MainScreen layout that depends on shell visibility state.
  Listenable get mainScreenLayoutListenable => _mainScreenLayoutNotifier;

  /// Sets the current shell mode.
  set shellMode(final ShellMode value) {
    if (_shellMode == value) {
      return;
    }
    _shellMode = value;
    _mainScreenLayoutNotifier.notifyListeners();
    update();
  }

  bool _isSidePanelExpanded = true;

  /// Gets whether the side panel is expanded.
  bool get isSidePanelExpanded => _isSidePanelExpanded;

  /// Listenable used by side-panel UI that only depends on expansion state.
  Listenable get sidePanelExpandedListenable => _sidePanelExpandedNotifier;

  /// Sets whether the side panel is expanded.
  set isSidePanelExpanded(final bool value) {
    if (_isSidePanelExpanded == value) {
      return;
    }
    _isSidePanelExpanded = value;
    _mainScreenLayoutNotifier.notifyListeners();
    _sidePanelExpandedNotifier.notifyListeners();
    update();
  }

  //=============================================================================
  // SidePanel Expanded/Collapsed
  bool _showMenu = false;

  /// Gets whether the menu is visible.
  bool get showMenu => _showMenu;

  /// Sets whether the menu is visible.
  set showMenu(final bool value) {
    _showMenu = value;
    _mainScreenLayoutNotifier.notifyListeners();
    update();
  }

  @override
  void dispose() {
    _mainScreenLayoutNotifier.dispose();
    _sidePanelExpandedNotifier.dispose();
    super.dispose();
  }
}
