import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/marching_ants_path.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';

enum _SelectionOverlayFeedbackMode {
  none,
  resize,
  scale,
  rotate,
}

/// A widget that displays a selection rectangle with handles for resizing and moving.
class SelectionRectWidget extends StatefulWidget {
  /// Creates a [SelectionRectWidget].
  ///
  /// The [path1] parameter specifies the primary path of the selection rectangle.
  /// The [path2] parameter specifies an optional secondary path for the selection rectangle.
  /// The [onDrag] parameter is a callback that is called when the selection rectangle is dragged.
  /// The [onResize] parameter is a callback that is called when the selection rectangle is resized.
  /// The [enableMoveAndResize] parameter specifies whether the selection rectangle can be moved and resized.
  const SelectionRectWidget({
    super.key,
    required this.path1,
    required this.path2,
    required this.onDrag,
    required this.onScale,
    required this.onResize,
    required this.onRotate,
    required this.onToggleTransformMode,
    required this.onCopy,
    required this.onDuplicate,
    required this.onApplyEffect,
    this.enableMoveAndResize = true,
    this.isDrawing = false,
  });

  /// Whether the selection rectangle can be moved and resized.
  final bool enableMoveAndResize;

  /// Whether a new selection is actively being drawn.
  final bool isDrawing;

  /// A callback that applies a [SelectionEffect] to the selected region at the given strength.
  final void Function(SelectionEffect effect, double strength) onApplyEffect;

  /// A callback that copies the selection to the clipboard.
  final VoidCallback onCopy;

  /// A callback that is called when the selection rectangle is dragged.
  final void Function(Offset) onDrag;

  /// A callback that duplicates the selection (copy then paste).
  final VoidCallback onDuplicate;

  /// A callback that is called when the selection rectangle is resized.
  final void Function(NineGridHandle, Offset) onResize;

  /// A callback that is called when the selection is rotated by [angleRadians].
  final void Function(double angleRadians) onRotate;

  /// A callback that is called when the selection is uniformly scaled.
  final void Function(double factor) onScale;

  /// A callback that toggles between resize/rotate and perspective/skew modes.
  final VoidCallback onToggleTransformMode;

  /// The primary path of the selection rectangle.
  final Path? path1;

  /// An optional secondary path for the selection rectangle.
  final Path? path2;
  @override
  State<SelectionRectWidget> createState() => _SelectionRectWidgetState();
}

const double defaultHandleSize = AppInteraction.selectionHandleSize;

class _SelectionRectWidgetState extends State<SelectionRectWidget> {
  Size _activeResizeDimensions = Size.zero;
  double _activeRotationDegrees = 0;
  double _activeScalePercent = AppMath.percentScale;
  _SelectionOverlayFeedbackMode _feedbackMode = _SelectionOverlayFeedbackMode.none;
  bool _showCoordinates = false;
  @override
  Widget build(final BuildContext context) {
    if (widget.path1 == null) {
      return const SizedBox();
    }

    final AppLocalizations l10n = context.l10n;
    final Rect bounds = widget.path1!.getBounds();
    final double modeToggleSize = AppInteraction.imagePlacementButtonSize;
    final double modeToggleSpacing = AppInteraction.imagePlacementButtonSpacing;
    final double controlsWidth = modeToggleSize * AppMath.triple + modeToggleSpacing * AppMath.pair;
    final double width = max(
      bounds.left + bounds.width + defaultHandleSize,
      bounds.center.dx + controlsWidth / AppMath.pair,
    );

    // Extra space above for the rotation handle stem + handle
    final double rotationOverhead = widget.enableMoveAndResize
        ? AppInteraction.rotationHandleDistance + modeToggleSize
        : 0;
    final double height = bounds.bottom + bounds.height + defaultHandleSize + rotationOverhead;

    final List<Widget> stackChildren = <Widget>[
      AnimatedMarchingAntsPath(path: widget.path1!),
      if (widget.path2 != null) AnimatedMarchingAntsPath(path: widget.path2!),
      _buildModeControls(bounds, l10n),
      if (widget.enableMoveAndResize && !widget.isDrawing) _buildBottomControls(bounds, l10n),
    ];

    if (widget.enableMoveAndResize) {
      stackChildren.addAll(<Widget>[
        // Center handle for moving
        OverlayDragHandle(
          position: bounds.center,
          cursor: SystemMouseCursors.move,
          showCoordinates: _showCoordinates,
          onPanUpdate: (final DragUpdateDetails details) {
            _beginHandleDrag();
            widget.onDrag(details.delta);
            _updateResizeFeedback();
          },
          onPanEnd: _endHandleDrag,
        ),

        // Top Left
        OverlayDragHandle(
          position: bounds.topLeft,
          cursor: SystemMouseCursors.resizeUpLeft,
          showCoordinates: _showCoordinates,
          onPanUpdate: (final DragUpdateDetails details) {
            _beginHandleDrag();
            widget.onResize(NineGridHandle.topLeft, details.delta);
            _updateResizeFeedback();
          },
          onPanEnd: _endHandleDrag,
        ),

        // Top Right
        OverlayDragHandle(
          position: bounds.topRight,
          cursor: SystemMouseCursors.resizeUpRight,
          showCoordinates: _showCoordinates,
          onPanUpdate: (final DragUpdateDetails details) {
            _beginHandleDrag();
            widget.onResize(NineGridHandle.topRight, details.delta);
            _updateResizeFeedback();
          },
          onPanEnd: _endHandleDrag,
        ),

        // Bottom Left
        OverlayDragHandle(
          position: bounds.bottomLeft,
          cursor: SystemMouseCursors.resizeDownLeft,
          showCoordinates: _showCoordinates,
          onPanUpdate: (final DragUpdateDetails details) {
            _beginHandleDrag();
            widget.onResize(NineGridHandle.bottomLeft, details.delta);
            _updateResizeFeedback();
          },
          onPanEnd: _endHandleDrag,
        ),

        // Bottom right
        OverlayDragHandle(
          position: bounds.bottomRight,
          cursor: SystemMouseCursors.resizeDownRight,
          showCoordinates: _showCoordinates,
          onPanUpdate: (final DragUpdateDetails details) {
            _beginHandleDrag();
            widget.onResize(NineGridHandle.bottomRight, details.delta);
            _updateResizeFeedback();
          },
          onPanEnd: _endHandleDrag,
        ),

        // Side Left
        OverlayDragHandle(
          position: Offset(bounds.left, bounds.center.dy),
          cursor: SystemMouseCursors.resizeLeft,
          showCoordinates: _showCoordinates,
          onPanUpdate: (final DragUpdateDetails details) {
            _beginHandleDrag();
            widget.onResize(NineGridHandle.left, details.delta);
            _updateResizeFeedback();
          },
          onPanEnd: _endHandleDrag,
        ),

        // Side Right
        OverlayDragHandle(
          position: Offset(bounds.right, bounds.center.dy),
          cursor: SystemMouseCursors.resizeRight,
          showCoordinates: _showCoordinates,
          onPanUpdate: (final DragUpdateDetails details) {
            _beginHandleDrag();
            widget.onResize(NineGridHandle.right, details.delta);
            _updateResizeFeedback();
          },
          onPanEnd: _endHandleDrag,
        ),

        // Center Top
        OverlayDragHandle(
          position: Offset(bounds.center.dx, bounds.top),
          cursor: SystemMouseCursors.resizeUp,
          showCoordinates: _showCoordinates,
          onPanUpdate: (final DragUpdateDetails details) {
            _beginHandleDrag();
            widget.onResize(NineGridHandle.top, details.delta);
            _updateResizeFeedback();
          },
          onPanEnd: _endHandleDrag,
        ),

        // Center Bottom
        OverlayDragHandle(
          position: Offset(bounds.center.dx, bounds.bottom),
          cursor: SystemMouseCursors.resizeDown,
          showCoordinates: _showCoordinates,
          onPanUpdate: (final DragUpdateDetails details) {
            _beginHandleDrag();
            widget.onResize(NineGridHandle.bottom, details.delta);
            _updateResizeFeedback();
          },
          onPanEnd: _endHandleDrag,
        ),
      ]);
    }

    return SizedBox(
      width: width < 0 ? 0 : width,
      height: height < 0 ? 0 : height,
      child: Stack(children: stackChildren),
    );
  }

  void _beginHandleDrag() {
    setState(() => _showCoordinates = true);
  }

  void _beginRotateFeedback() {
    setState(() {
      _feedbackMode = _SelectionOverlayFeedbackMode.rotate;
      _activeRotationDegrees = 0;
    });
  }

  void _beginScaleFeedback() {
    setState(() {
      _feedbackMode = _SelectionOverlayFeedbackMode.scale;
      _activeScalePercent = AppMath.percentScale;
    });
  }

  /// Builds the copy-to-clipboard control shown below the selection.
  Widget _buildBottomControls(
    final Rect bounds,
    final AppLocalizations l10n,
  ) {
    final double buttonSize = AppInteraction.imagePlacementButtonSize;
    final double spacing = AppInteraction.imagePlacementButtonSpacing;
    final double controlsWidth = buttonSize * AppMath.triple + spacing * AppMath.pair;
    final double controlsTop = bounds.bottom + AppInteraction.imagePlacementButtonSpacing;

    return Positioned(
      left: bounds.center.dx - controlsWidth / AppMath.pair,
      top: controlsTop,
      child: Row(
        spacing: spacing,
        children: <Widget>[
          buildOverlayCircleButton(
            tooltip: l10n.copyToClipboard,
            color: AppColors.selected,
            cursor: SystemMouseCursors.click,
            onTap: widget.onCopy,
            child: const AppSvgIcon(icon: AppIcon.clipboardCopy, size: AppLayout.iconSize, color: AppPalette.white),
          ),
          buildOverlayCircleButton(
            tooltip: l10n.duplicate,
            color: AppColors.selected,
            cursor: SystemMouseCursors.click,
            onTap: widget.onDuplicate,
            child: const AppSvgIcon(icon: AppIcon.copy, size: AppLayout.iconSize, color: AppPalette.white),
          ),
          _EffectsPopupButton(
            l10n: l10n,
            onApplyEffect: widget.onApplyEffect,
          ),
        ],
      ),
    );
  }

  /// Builds the scale, rotate, and transform mode controls shown above the selection.
  Widget _buildModeControls(
    final Rect bounds,
    final AppLocalizations l10n,
  ) {
    final double buttonSize = AppInteraction.imagePlacementButtonSize;
    final double spacing = AppInteraction.imagePlacementButtonSpacing;
    final double controlsWidth = buttonSize * AppMath.triple + spacing * AppMath.pair;
    final double controlsTop = bounds.top - AppInteraction.rotationHandleDistance - buttonSize / AppMath.pair;
    final double controlsLeft = bounds.center.dx - controlsWidth / AppMath.pair;
    final Offset scaleHandleCenter = Offset(
      controlsLeft + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );
    final Offset rotateHandleCenter = Offset(
      controlsLeft + buttonSize + spacing + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );

    return Positioned(
      left: controlsLeft,
      top: _isFeedbackVisible ? controlsTop - buttonSize : controlsTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_isFeedbackVisible) buildOverlayFeedbackBubble(label: _feedbackLabel(l10n)),
          if (_isFeedbackVisible) const SizedBox(height: AppInteraction.imagePlacementButtonSpacing),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: spacing,
            children: <Widget>[
              buildOverlayCircleButton(
                tooltip: l10n.scale,
                color: AppColors.selected,
                cursor: SystemMouseCursors.grab,
                onPanStart: (final DragStartDetails _) => _beginScaleFeedback(),
                onPanUpdate: (final DragUpdateDetails details) {
                  final double previousDistance = (scaleHandleCenter - bounds.center).distance;
                  final Offset pointer = scaleHandleCenter + details.delta;
                  final double currentDistance = (pointer - bounds.center).distance;
                  if (previousDistance <= AppMath.tinyPercentage) {
                    return;
                  }
                  final double factor = currentDistance / previousDistance;
                  _updateScaleFeedback(factor);
                  widget.onScale(factor);
                },
                onPanEnd: (final DragEndDetails _) => _endFeedback(),
                onPanCancel: _endFeedback,
                child: const AppSvgIcon(icon: AppIcon.openInFull, size: AppLayout.iconSize, color: AppPalette.white),
              ),
              buildOverlayCircleButton(
                tooltip: l10n.resizeRotate,
                color: AppPalette.green,
                cursor: SystemMouseCursors.grab,
                onPanStart: (final DragStartDetails _) => _beginRotateFeedback(),
                onPanUpdate: (final DragUpdateDetails details) {
                  final Offset pointer = rotateHandleCenter + details.delta;
                  final double previousAngle = atan2(
                    rotateHandleCenter.dy - bounds.center.dy,
                    rotateHandleCenter.dx - bounds.center.dx,
                  );
                  final double currentAngle = atan2(
                    pointer.dy - bounds.center.dy,
                    pointer.dx - bounds.center.dx,
                  );
                  final double angleDelta = currentAngle - previousAngle;
                  _updateRotateFeedback(angleDelta);
                  widget.onRotate(angleDelta);
                },
                onPanEnd: (final DragEndDetails _) => _endFeedback(),
                onPanCancel: _endFeedback,
                child: const AppSvgIcon(icon: AppIcon.rotateRight, size: AppLayout.iconSize, color: AppPalette.white),
              ),
              buildOverlayCircleButton(
                tooltip: l10n.transform,
                color: AppColors.transformCornerHandle,
                cursor: SystemMouseCursors.click,
                onTap: widget.onToggleTransformMode,
                child: const AppSvgIcon(icon: AppIcon.transform),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _endFeedback() {
    setState(() {
      _feedbackMode = _SelectionOverlayFeedbackMode.none;
      _activeScalePercent = AppMath.percentScale;
      _activeRotationDegrees = 0;
      _activeResizeDimensions = Size.zero;
    });
  }

  void _endHandleDrag() {
    setState(() => _showCoordinates = false);
    _endFeedback();
  }

  /// Returns the localized label for the active feedback bubble.
  String _feedbackLabel(final AppLocalizations l10n) {
    if (widget.isDrawing && widget.path1 != null) {
      final Rect bounds = widget.path1!.getBounds();
      return l10n.dimensionsValue(
        bounds.width.round(),
        bounds.height.round(),
      );
    }
    switch (_feedbackMode) {
      case _SelectionOverlayFeedbackMode.scale:
        return l10n.percentageValue(_activeScalePercent.round());
      case _SelectionOverlayFeedbackMode.rotate:
        return l10n.degreesValue(_activeRotationDegrees.round());
      case _SelectionOverlayFeedbackMode.resize:
        return l10n.dimensionsValue(
          _activeResizeDimensions.width.round(),
          _activeResizeDimensions.height.round(),
        );
      case _SelectionOverlayFeedbackMode.none:
        return '';
    }
  }

  bool get _isFeedbackVisible => _feedbackMode != _SelectionOverlayFeedbackMode.none || widget.isDrawing;

  /// Updates the resize dimensions feedback from the current path bounds.
  void _updateResizeFeedback() {
    if (widget.path1 == null) {
      return;
    }
    setState(() {
      _feedbackMode = _SelectionOverlayFeedbackMode.resize;
      final Rect bounds = widget.path1!.getBounds();
      _activeResizeDimensions = bounds.size;
    });
  }

  /// Accumulates [angleRadians] into the live rotation feedback and triggers
  /// haptic feedback when the cumulative angle crosses a snap interval.
  void _updateRotateFeedback(final double angleRadians) {
    setState(() {
      if (_feedbackMode != _SelectionOverlayFeedbackMode.rotate) {
        _feedbackMode = _SelectionOverlayFeedbackMode.rotate;
        _activeRotationDegrees = 0;
      }
      final double previousDegrees = _activeRotationDegrees;
      _activeRotationDegrees += angleRadians * AppMath.degreesPerHalfTurn / pi;
      triggerRotationSnapHaptic(previousDegrees, _activeRotationDegrees);
    });
  }

  /// Multiplies the live scale percentage by [factor] and triggers haptic
  /// feedback when the cumulative scale crosses a snap interval.
  void _updateScaleFeedback(final double factor) {
    setState(() {
      if (_feedbackMode != _SelectionOverlayFeedbackMode.scale) {
        _feedbackMode = _SelectionOverlayFeedbackMode.scale;
        _activeScalePercent = AppMath.percentScale;
      }
      final double previousPercent = _activeScalePercent;
      _activeScalePercent *= factor;
      triggerScaleSnapHaptic(previousPercent, _activeScalePercent);
    });
  }
}

/// A circular button that opens a popup menu of [SelectionEffect] options.
class _EffectsPopupButton extends StatefulWidget {
  const _EffectsPopupButton({
    required this.l10n,
    required this.onApplyEffect,
  });
  final AppLocalizations l10n;
  final void Function(SelectionEffect effect, double strength) onApplyEffect;

  @override
  State<_EffectsPopupButton> createState() => _EffectsPopupButtonState();
}

class _EffectsPopupButtonState extends State<_EffectsPopupButton> {
  @override
  Widget build(final BuildContext context) {
    return buildOverlayCircleButton(
      key: Keys.effectsButton,
      tooltip: widget.l10n.effects,
      color: AppColors.selected,
      cursor: SystemMouseCursors.click,
      onTap: () => _showEffectsMenu(context),
      child: const AppSvgIcon(
        icon: AppIcon.autoFixHigh,
        size: AppLayout.iconSize,
        color: AppPalette.white,
      ),
    );
  }

  /// Opens a popup menu anchored below this button listing all available
  /// [SelectionEffect] options with their icons and localized labels.
  void _showEffectsMenu(final BuildContext context) {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(button.size.width / AppMath.pair, button.size.height),
    );

    showAppMenu<SelectionEffect>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx,
        offset.dy,
      ),
      items: SelectionEffect.values
          .map(
            (final SelectionEffect effect) => AppPopupMenuItem<SelectionEffect>(
              value: effect,
              child: Row(
                spacing: AppSpacing.md,
                children: <Widget>[
                  AppSvgIcon(
                    icon: effect.icon,
                    size: AppLayout.iconSize,
                  ),
                  Text(effectLabel(widget.l10n, effect)),
                ],
              ),
            ),
          )
          .toList(),
    ).then((final SelectionEffect? selected) {
      if (mounted && selected != null) {
        // ignore: use_build_context_synchronously
        _showIntensityDialog(context, selected);
      }
    });
  }

  /// Shows a dialog with a slider so the user can choose the effect intensity
  /// before it is applied.
  void _showIntensityDialog(final BuildContext context, final SelectionEffect effect) {
    showAppDialog<double>(
      context: context,
      builder: (final BuildContext _) => _EffectIntensityDialog(
        l10n: widget.l10n,
        effect: effect,
        onApply: (final double strength) => widget.onApplyEffect(effect, strength),
      ),
    );
  }
}

/// Dialog that lets the user set an effect's intensity via a slider before
/// the effect is committed to the canvas.
class _EffectIntensityDialog extends StatefulWidget {
  const _EffectIntensityDialog({
    required this.l10n,
    required this.effect,
    required this.onApply,
  });
  final SelectionEffect effect;
  final AppLocalizations l10n;

  /// Called with the chosen strength (0.0–1.0) when the user taps Apply.
  final void Function(double strength) onApply;
  @override
  State<_EffectIntensityDialog> createState() => _EffectIntensityDialogState();
}

class _EffectIntensityDialogState extends State<_EffectIntensityDialog> {
  double _strength = AppEffects.defaultIntensity;

  @override
  Widget build(final BuildContext context) {
    return AppDialog(
      title: Row(
        spacing: AppSpacing.md,
        children: <Widget>[
          AppSvgIcon(icon: widget.effect.icon, size: AppLayout.iconSize),
          Text(effectLabel(widget.l10n, widget.effect)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${widget.l10n.effectIntensity} (${(_strength * AppMath.percentScale).round()}%)'),
          AppSlider(
            key: Keys.effectIntensityDialogSlider,
            value: _strength,
            min: AppEffects.minIntensity,
            max: AppEffects.maxIntensity,
            onChanged: (final double value) => setState(() => _strength = value),
          ),
        ],
      ),
      actions: <Widget>[
        AppTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.cancel),
        ),
        AppElevatedButton(
          key: Keys.effectIntensityApplyButton,
          onPressed: () {
            Navigator.of(context).pop(_strength);
            widget.onApply(_strength);
          },
          child: Text(widget.l10n.apply),
        ),
      ],
    );
  }
}
