part of 'app_provider.dart';

/// Adapts [AppProvider] to the tool rail's [ToolRailPort].
class _AppToolRail implements ToolRailPort {
  _AppToolRail(this._app);

  final AppProvider _app;

  @override
  late final Listenable railChanges = Listenable.merge(<Listenable>[
    _app.selectedActionRepaintListenable,
    _app.toolOptionsRepaintListenable,
  ]);

  @override
  ToolKind get selectedTool => _app.selectedTool;

  @override
  ToolDescriptor get activeTool => _app.activeTool;

  @override
  void activateTool(ToolDescriptor tool) => _app.activateTool(tool);

  @override
  SelectionEffect? get armedEffect => _app.effectBrushModel.effect;

  @override
  void armEffectBrush(SelectionEffect effect) => _app.armEffectBrush(effect);

  @override
  void disarmEffectBrush() => _app.disarmEffectBrush();

  @override
  double get effectStrength => _app.effectBrushModel.strength;

  @override
  void setEffectStrength(double value) => _app.setEffectBrushStrength(value);

  @override
  double get brushSize => _app.brushSize;

  @override
  set brushSize(double value) => _app.brushSize = value;
}
