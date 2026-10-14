part of 'app_provider.dart';

/// The shared "append actions to N layers as one undo entry" record behind
/// region replace, cross-layer cut/erase/transform, painted effects and
/// selected-layer drawing actions.
extension AppProviderLayerAppend on AppProvider {
  /// Records [name] as one undo entry that appends the actions
  /// [buildActions] returns for each of [resolveTargets]' layers, and undoes
  /// them in reverse (last layer first, each layer's actions popped in turn).
  ///
  /// [resolveTargets] runs on every apply/replay, so a target such as "the
  /// selected layer" is resolved when the record runs, exactly as callers
  /// that read it inside their closures did. [buildActions] receives the
  /// target's index and also runs on every apply, so a caller can return a
  /// fresh action per redo or deliberately share one instance. When
  /// [notifyAfterReplay] is true each apply/replay ends with [update].
  ///
  /// [retainedImages] are the textures the record can resurrect; see
  /// [UndoProvider.executeAction].
  void _executeLayerAppend({
    required String name,
    required List<LayerProvider> Function() resolveTargets,
    required List<UserActionDrawing> Function(int) buildActions,
    List<ui.Image> retainedImages = const <ui.Image>[],
    bool notifyAfterReplay = true,
  }) {
    // Per target, how many actions the latest forward appended, so backward
    // pops exactly those.
    final List<int> appendedCounts = <int>[];

    undoProvider.executeAction(
      name: name,
      retainedImages: retainedImages,
      forward: () {
        appendedCounts.clear();
        final List<LayerProvider> targets = resolveTargets();
        for (int i = AppMath.zero; i < targets.length; i++) {
          final List<UserActionDrawing> actions = buildActions(i);
          actions.forEach(targets[i].appendDrawingAction);
          appendedCounts.add(actions.length);
        }
        if (notifyAfterReplay) {
          update();
        }
      },
      backward: () {
        final List<LayerProvider> targets = resolveTargets();
        for (int i = targets.length - AppMath.one; i >= AppMath.zero; i--) {
          for (int n = AppMath.zero; n < appendedCounts[i]; n++) {
            targets[i].undo();
          }
        }
        if (notifyAfterReplay) {
          update();
        }
      },
    );
  }

  /// The selected layer as a one-element target list, resolved on each call.
  List<LayerProvider> _selectedLayerTarget() => <LayerProvider>[layers.selectedLayer];
}
