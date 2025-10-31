/// A base class for models that have visibility state.
abstract class VisibleModel {
  /// Whether this model is visible.
  bool isVisible = false;

  /// Clears the model state and hides it.
  void clear() {
    isVisible = false;
  }
}
