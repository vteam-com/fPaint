// Imports
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum ShellMode {
  hidden,
  minimal,
  full,
}

class ShellProvider extends ChangeNotifier {
  static ShellProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) =>
      Provider.of<ShellProvider>(context, listen: listen);

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }

  String loadedFileName = '';
  bool deviceSizeSmall = false;
  bool centerImageInViewPort = true;
  bool fitCanvasIntoScreen = true;

//=============================================================================
  // Shell
  ShellMode shellMode = ShellMode.full;

  bool _isSidePanelExpanded = true;
  bool get isSidePanelExpanded => _isSidePanelExpanded;
  set isSidePanelExpanded(final bool value) {
    _isSidePanelExpanded = value;
    update();
  }

  //=============================================================================
  // SidePanel Expanded/Collapsed
  bool _showMenu = false;
  bool get showMenu => _showMenu;
  set showMenu(final bool value) {
    _showMenu = value;
    update();
  }
}
