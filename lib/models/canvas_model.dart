// Imports
import 'package:flutter/material.dart';

// Exports
export 'package:fpaint/models/layers.dart';

class CanvasModel extends ChangeNotifier {
  Size canvasSize = const Size(800, 600); // Default canvas size

  //-------------------------------------------
  // canvasResizeLockAspectRatio
  bool _resizeLockAspectRatio = true;
  bool get canvasResizeLockAspectRatio => _resizeLockAspectRatio;

  set canvasResizeLockAspectRatio(bool value) {
    _resizeLockAspectRatio = value;
    notifyListeners();
  }

  //-------------------------------------------
  // Scale
  double _scale = 1;
  double get scale => _scale;
  set scale(double value) {
    _scale = value;
    notifyListeners();
  }

  //-------------------------------------------
  // Canvas Resize position
  int _resizePosition = 4; // Center

  int get resizePosition => _resizePosition;

  set resizePosition(int value) {
    _resizePosition = value;
    notifyListeners();
  } // center
}
