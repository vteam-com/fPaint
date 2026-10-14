import 'dart:ui' as ui;

import 'package:fpaint/models/user_action_drawing.dart';

/// Immutable capture of a layer's restorable content state.
///
/// Produced by `LayerProvider.captureSnapshot` and consumed by
/// `LayerProvider.restoreFromSnapshot`, so every flow that floats, replaces, or
/// rewrites a layer (layer modify, paste-commit undo, crop undo, pixel-brush
/// undo) captures and restores the exact same set of fields instead of each
/// hand-picking its own subset.
class LayerStateSnapshot {
  const LayerStateSnapshot({
    required this.actions,
    required this.redoActions,
    required this.hasChanged,
    required this.backgroundColor,
    required this.blendMode,
    required this.opacity,
  });

  /// The layer's action stack at capture time.
  final List<UserActionDrawing> actions;

  /// The layer's redo stack at capture time.
  final List<UserActionDrawing> redoActions;

  /// Whether the layer had unsaved changes at capture time.
  final bool hasChanged;

  /// The layer's background color at capture time, if any.
  final ui.Color? backgroundColor;

  /// The layer's blend mode at capture time.
  final ui.BlendMode blendMode;

  /// The layer's opacity at capture time.
  final double opacity;

  /// Every GPU texture a restore of this snapshot reintroduces: the images of
  /// both [actions] and [redoActions].
  ///
  /// Undo records that restore this snapshot list these as retained images so
  /// their disposal waits until the record leaves history.
  List<ui.Image> get images => <ui.Image>[
    ...imagesOf(actions),
    ...imagesOf(redoActions),
  ];

  /// The non-null images carried by [actions], in order.
  static List<ui.Image> imagesOf(Iterable<UserActionDrawing> actions) => <ui.Image>[
    for (final UserActionDrawing action in actions)
      if (action.image != null) action.image!,
  ];
}
