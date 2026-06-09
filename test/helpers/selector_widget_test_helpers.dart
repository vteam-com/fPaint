import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/app_tooltip.dart';

/// Default callback implementations for SelectionRectWidget tests.
typedef SelectionRectCallbacks = ({
  VoidCallback onCancel,
  Future<void> Function() onCopy,
  Future<void> Function() onDuplicate,
  Future<void> Function(Offset offset, bool duplicateOnNewLayer)? onDuplicateMove,
  VoidCallback onToggleTransformMode,
  void Function(Offset) onDrag,
  void Function(NineGridHandle, Offset) onResize,
  void Function(double) onScale,
  void Function(double) onRotate,
  Future<void> Function(SelectionEffect effect, BuildContext context) onEffectSelected,
});

/// Creates default selector widget callbacks.
/// Individual callbacks can be overridden by passing them as parameters.
SelectionRectCallbacks createDefaultSelectionRectCallbacks({
  VoidCallback? onCancel,
  Future<void> Function()? onCopy,
  Future<void> Function()? onDuplicate,
  Future<void> Function(Offset offset, bool duplicateOnNewLayer)? onDuplicateMove,
  VoidCallback? onToggleTransformMode,
  void Function(Offset)? onDrag,
  void Function(NineGridHandle, Offset)? onResize,
  void Function(double)? onScale,
  void Function(double)? onRotate,
  Future<void> Function(SelectionEffect effect, BuildContext context)? onEffectSelected,
}) {
  return (
    onCancel: onCancel ?? () {},
    onCopy: onCopy ?? () async {},
    onDuplicate: onDuplicate ?? () async {},
    onDuplicateMove: onDuplicateMove,
    onToggleTransformMode: onToggleTransformMode ?? () {},
    onDrag: onDrag ?? (final Offset _) {},
    onResize: onResize ?? (final NineGridHandle _, final Offset _) {},
    onScale: onScale ?? (final double _) {},
    onRotate: onRotate ?? (final double _) {},
    onEffectSelected: onEffectSelected ?? (final SelectionEffect _, final BuildContext _) async {},
  );
}

/// Finds an AppTooltip widget by its message text.
Finder findTooltipByMessage(String message) {
  return find.byWidgetPredicate(
    (final Widget widget) => widget is AppTooltip && widget.message == message,
  );
}
