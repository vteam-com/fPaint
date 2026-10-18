/// The viewport and whole-canvas commands the top bar's view controls invoke.
///
/// A role interface rather than the whole app provider (Interface
/// Segregation): the zoom, rotate, flip and fit buttons need nothing else.
abstract interface class CanvasViewCommands {
  /// Zooms by [scaleDelta] about the canvas centre.
  void zoomAboutCenter(double scaleDelta);

  /// Rotates the selection, or the whole canvas, 90 degrees clockwise.
  Future<void> rotateCanvas90(String actionName);

  /// Flips the selection, or the whole canvas, left to right.
  Future<void> flipCanvasHorizontal(String actionName);

  /// Flips the selection, or the whole canvas, top to bottom.
  Future<void> flipCanvasVertical(String actionName);

  /// Turns the viewport back upright.
  void resetCanvasRotation();

  /// Rebuilds viewport-dependent UI.
  void repaintViewport();
}
