// Imports
import 'package:flutter/material.dart';

// Exports
export 'package:fpaint/models/layers.dart';

const int topLeft = 0;
const int top = 1;
const int topRight = 2;
const int left = 3;
const int center = 4;
const int right = 5;
const int bottomLeft = 6;
const int bottom = 7;
const int bottomRight = 8;

class CanvasModel extends ChangeNotifier {
  Size canvasSize = const Size(800, 600); // Default canvas size

  //-------------------------------------------
  bool _canvasResizeLockAspectRatio = true;

  bool get canvasResizeLockAspectRatio => _canvasResizeLockAspectRatio;

  set canvasResizeLockAspectRatio(bool value) {
    _canvasResizeLockAspectRatio = value;
    notifyListeners();
  }
}
