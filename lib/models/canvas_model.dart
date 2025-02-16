// Imports
import 'package:flutter/material.dart';

// Exports
export 'package:fpaint/providers/layers_provider.dart';

class CanvasModel extends ChangeNotifier {
  ///-------------------------------------------
  /// Default canvas size
  Size size = const Size(800, 600);
  double get width => this.size.width * this.scale;
  double get height => this.size.height * this.scale;

  ///-------------------------------------------
  /// canvasResizeLockAspectRatio
  bool _resizeLockAspectRatio = true;
  bool get canvasResizeLockAspectRatio => _resizeLockAspectRatio;

  set canvasResizeLockAspectRatio(bool value) {
    _resizeLockAspectRatio = value;
    notifyListeners();
  }

  ///-------------------------------------------
  /// Scale
  /// Sets the scale of the canvas.
  ///
  /// The scale value is clamped between 10% and 400% to ensure a valid range.
  /// Calling this method will notify any listeners of the [AppModel] that the scale has changed.
  double _scale = 1;
  double get scale => _scale;
  set scale(double value) {
    _scale = value.clamp(10 / 100, 400 / 100);
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
