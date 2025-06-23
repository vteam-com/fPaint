// Imports
import 'dart:core';

import 'package:flutter/material.dart';
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
  /// Retrieves the [ShellProvider] instance from the given [BuildContext].
  ///
  /// The [listen] parameter determines whether the widget should rebuild when the
  /// [ShellProvider]'s state changes.
  static ShellProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) => Provider.of<ShellProvider>(context, listen: listen);

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }

  /// The name of the loaded file.
  String loadedFileName = '';

  /// Whether the device size is small.
  bool deviceSizeSmall = false;

  /// The canvas auto placement setting.
  CanvasAutoPlacement canvasPlacement = CanvasAutoPlacement.fit;

  //=============================================================================
  // Shell
  /// The current shell mode.
  ShellMode shellMode = ShellMode.full;

  bool _isSidePanelExpanded = true;

  /// Gets whether the side panel is expanded.
  bool get isSidePanelExpanded => _isSidePanelExpanded;

  /// Sets whether the side panel is expanded.
  set isSidePanelExpanded(final bool value) {
    _isSidePanelExpanded = value;
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
    update();
  }
}
