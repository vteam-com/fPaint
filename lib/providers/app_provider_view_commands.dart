part of 'app_provider.dart';

/// Adapts [AppProvider] to the top bar's [CanvasViewCommands].
class _AppCanvasViewCommands implements CanvasViewCommands {
  _AppCanvasViewCommands(this._app);

  final AppProvider _app;

  @override
  void zoomAboutCenter(double scaleDelta) => _app.zoomAboutCenter(scaleDelta);

  @override
  Future<void> rotateCanvas90(String actionName) => _app.rotateCanvas90(actionName);

  @override
  Future<void> flipCanvasHorizontal(String actionName) => _app.flipCanvasHorizontal(actionName);

  @override
  Future<void> flipCanvasVertical(String actionName) => _app.flipCanvasVertical(actionName);

  @override
  void resetCanvasRotation() => _app.resetCanvasRotation();

  @override
  void repaintViewport() => _app.repaintViewport();
}
