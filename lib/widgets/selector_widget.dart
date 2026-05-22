import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/marching_ants_path.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';

enum _SelectionOverlayFeedbackMode {
  none,
  translate,
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
    required this.onCancel,
    required this.onCopy,
    required this.onDuplicate,
    required this.onEffectSelected,
    this.enableMoveAndResize = true,
    this.isDrawing = false,
  });

  /// Whether the selection rectangle can be moved and resized.
  final bool enableMoveAndResize;

  /// Whether a new selection is actively being drawn.
  final bool isDrawing;

  /// A callback that cancels the selection.
  final VoidCallback onCancel;

  /// A callback that copies the selection to the clipboard.
  final VoidCallback onCopy;

  /// A callback that is called when the selection rectangle is dragged.
  final void Function(Offset) onDrag;

  /// A callback that duplicates the selection (copy then paste).
  final VoidCallback onDuplicate;

  /// Called when the user selects an effect from the popup menu.
  /// Receives the chosen [SelectionEffect] and the [BuildContext] of the
  /// popup button so the caller can start a live preview and show a bottom sheet.
  final Future<void> Function(SelectionEffect effect, BuildContext context) onEffectSelected;

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

/// Metadata describing one resize handle of the selection rectangle.
class _HandleDescriptor {
  const _HandleDescriptor({
    required this.handle,
    required this.cursor,
    required this.position,
  });

  /// The mouse cursor to show while hovering.
  final MouseCursor cursor;

  /// Which grid handle this represents.
  final NineGridHandle handle;

  /// Computes the screen position from the selection bounds.
  final Offset Function(Rect bounds) position;
}

/// All eight resize handles around the selection rectangle.
const List<_HandleDescriptor> _resizeHandles = <_HandleDescriptor>[
  _HandleDescriptor(
    handle: NineGridHandle.topLeft,
    cursor: SystemMouseCursors.resizeUpLeft,
    position: _topLeft,
  ),
  _HandleDescriptor(
    handle: NineGridHandle.topRight,
    cursor: SystemMouseCursors.resizeUpRight,
    position: _topRight,
  ),
  _HandleDescriptor(
    handle: NineGridHandle.bottomLeft,
    cursor: SystemMouseCursors.resizeDownLeft,
    position: _bottomLeft,
  ),
  _HandleDescriptor(
    handle: NineGridHandle.bottomRight,
    cursor: SystemMouseCursors.resizeDownRight,
    position: _bottomRight,
  ),
  _HandleDescriptor(
    handle: NineGridHandle.left,
    cursor: SystemMouseCursors.resizeLeft,
    position: _centerLeft,
  ),
  _HandleDescriptor(
    handle: NineGridHandle.right,
    cursor: SystemMouseCursors.resizeRight,
    position: _centerRight,
  ),
  _HandleDescriptor(
    handle: NineGridHandle.top,
    cursor: SystemMouseCursors.resizeUp,
    position: _centerTop,
  ),
  _HandleDescriptor(
    handle: NineGridHandle.bottom,
    cursor: SystemMouseCursors.resizeDown,
    position: _centerBottom,
  ),
];

Offset _topLeft(final Rect b) => b.topLeft;
Offset _topRight(final Rect b) => b.topRight;
Offset _bottomLeft(final Rect b) => b.bottomLeft;
Offset _bottomRight(final Rect b) => b.bottomRight;
Offset _centerLeft(final Rect b) => Offset(b.left, b.center.dy);
Offset _centerRight(final Rect b) => Offset(b.right, b.center.dy);
Offset _centerTop(final Rect b) => Offset(b.center.dx, b.top);
Offset _centerBottom(final Rect b) => Offset(b.center.dx, b.bottom);

class _SelectionRectWidgetState extends State<SelectionRectWidget> {
  Size _activeResizeDimensions = Size.zero;
  double _activeRotationDegrees = 0;
  double _activeScalePercent = AppMath.percentScale;
  _SelectionOverlayFeedbackMode _feedbackMode = _SelectionOverlayFeedbackMode.none;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Request focus when the widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    if (widget.path1 == null) {
      return const SizedBox();
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Rect bounds = widget.path1!.getBounds();
    const double modeToggleSize = AppInteraction.imagePlacementButtonSize;
    const double modeToggleSpacing = AppInteraction.imagePlacementButtonSpacing;
    const double controlsWidth = modeToggleSize * AppMath.four + modeToggleSpacing * AppMath.triple;
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
      // Center handle for moving
      stackChildren.add(
        OverlayDragHandle(
          position: bounds.center,
          cursor: SystemMouseCursors.move,
          onPanUpdate: (final DragUpdateDetails details) {
            widget.onDrag(details.delta);
            _updateResizeFeedback();
          },
          onPanEnd: _endFeedback,
        ),
      );

      // Resize handles driven by metadata
      for (final _HandleDescriptor desc in _resizeHandles) {
        stackChildren.add(
          OverlayDragHandle(
            position: desc.position(bounds),
            cursor: desc.cursor,
            onPanUpdate: (final DragUpdateDetails details) {
              widget.onResize(desc.handle, details.delta);
              _updateResizeFeedback();
            },
            onPanEnd: _endFeedback,
          ),
        );
      }
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (final FocusNode _, final KeyEvent _) {
        if (HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.escape)) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: width < 0 ? 0 : width,
        height: height < 0 ? 0 : height,
        child: Stack(children: stackChildren),
      ),
    );
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

  void _beginTranslateFeedback() {
    setState(() {
      _feedbackMode = _SelectionOverlayFeedbackMode.translate;
    });
  }

  /// Builds the copy-to-clipboard control shown below the selection.
  Widget _buildBottomControls(
    final Rect bounds,
    final AppLocalizations l10n,
  ) {
    const double buttonSize = AppInteraction.imagePlacementButtonSize;
    const double spacing = AppInteraction.imagePlacementButtonSpacing;
    const double controlsWidth = buttonSize * AppMath.triple + spacing * AppMath.pair;
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
            child: const AppSvgIcon(icon: AppIcon.clipboardCopy, size: AppLayout.iconSize, color: AppColors.white),
          ),
          buildOverlayCircleButton(
            tooltip: l10n.duplicate,
            color: AppColors.selected,
            cursor: SystemMouseCursors.click,
            onTap: widget.onDuplicate,
            child: const AppSvgIcon(icon: AppIcon.copy, size: AppLayout.iconSize, color: AppColors.white),
          ),
          _EffectsPopupButton(
            l10n: l10n,
            onEffectSelected: widget.onEffectSelected,
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
    const int placementTop = AppMath.zero;
    const int placementBottom = AppMath.one;
    const int placementCenter = AppMath.pair;
    const double buttonSize = AppInteraction.imagePlacementButtonSize;
    const double spacing = AppInteraction.imagePlacementButtonSpacing;
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double controlsHeight = _isFeedbackVisible
        ? buttonSize + AppInteraction.imagePlacementButtonSpacing + buttonSize
        : buttonSize;
    const double controlsWidth = buttonSize * AppMath.four + spacing * AppMath.triple;
    final double idealControlsTop = bounds.top - AppInteraction.rotationHandleDistance - buttonSize / AppMath.pair;
    final double bottomControlsTop = bounds.bottom + AppInteraction.rotationHandleDistance;
    final double topPositionedTop = _isFeedbackVisible ? idealControlsTop - buttonSize : idealControlsTop;
    final bool topClips = topPositionedTop < 0;
    final bool bottomClips = bottomControlsTop + controlsHeight > viewportHeight;

    final int placement = !topClips ? placementTop : (!bottomClips ? placementBottom : placementCenter);
    final double centeredTop = max(AppMath.zero.toDouble(), (viewportHeight - controlsHeight) / AppMath.pair);
    final bool isFlippedToBottom = placement == placementBottom;
    final bool isCentered = placement == placementCenter;
    final double controlsTop = isCentered
        ? centeredTop + (_isFeedbackVisible ? buttonSize + AppInteraction.imagePlacementButtonSpacing : 0)
        : (isFlippedToBottom ? bottomControlsTop : idealControlsTop);
    final double controlsLeft = bounds.center.dx - controlsWidth / AppMath.pair;
    final Offset translateHandleCenter = Offset(
      controlsLeft + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );
    final Offset scaleHandleCenter = Offset(
      controlsLeft + buttonSize + spacing + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );
    final Offset rotateHandleCenter = Offset(
      controlsLeft + (buttonSize + spacing) * AppMath.pair + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );

    final Widget feedbackBubble = buildOverlayFeedbackBubble(label: _feedbackLabel(l10n));
    final Widget feedbackSpacer = const SizedBox(height: AppInteraction.imagePlacementButtonSpacing);
    final Widget buttonsRow = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: spacing,
      children: <Widget>[
        buildOverlayModeButton(
          tooltip: l10n.translate,
          icon: AppIcon.move,
          isSelected: _feedbackMode == _SelectionOverlayFeedbackMode.translate,
          cursor: SystemMouseCursors.move,
          onPanStart: (final DragStartDetails _) => _beginTranslateFeedback(),
          onPanUpdate: (final DragUpdateDetails details) {
            final Offset pointer = translateHandleCenter + details.delta;
            widget.onDrag(pointer - translateHandleCenter);
            _beginTranslateFeedback();
          },
          onPanEnd: (final DragEndDetails _) => _endFeedback(),
          onPanCancel: _endFeedback,
        ),
        buildOverlayModeButton(
          tooltip: l10n.scale,
          icon: AppIcon.openInFull,
          isSelected: _feedbackMode == _SelectionOverlayFeedbackMode.scale,
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
        ),
        buildOverlayModeButton(
          tooltip: l10n.resizeRotate,
          icon: AppIcon.rotateRight,
          isSelected: _feedbackMode == _SelectionOverlayFeedbackMode.rotate,
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
        ),
        buildOverlayModeButton(
          tooltip: l10n.transform,
          icon: AppIcon.transform,
          cursor: SystemMouseCursors.click,
          onTap: widget.onToggleTransformMode,
        ),
      ],
    );

    final double positionedTop;
    final List<Widget> columnChildren;
    if (isCentered) {
      positionedTop = centeredTop;
      columnChildren = <Widget>[
        if (_isFeedbackVisible) feedbackBubble,
        if (_isFeedbackVisible) feedbackSpacer,
        buttonsRow,
      ];
    } else if (isFlippedToBottom) {
      positionedTop = controlsTop;
      columnChildren = <Widget>[
        buttonsRow,
        if (_isFeedbackVisible) feedbackSpacer,
        if (_isFeedbackVisible) feedbackBubble,
      ];
    } else {
      positionedTop = _isFeedbackVisible ? controlsTop - buttonSize : controlsTop;
      columnChildren = <Widget>[
        if (_isFeedbackVisible) feedbackBubble,
        if (_isFeedbackVisible) feedbackSpacer,
        buttonsRow,
      ];
    }

    return Positioned(
      left: controlsLeft,
      top: positionedTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: columnChildren,
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
      case _SelectionOverlayFeedbackMode.translate:
        return '';
      case _SelectionOverlayFeedbackMode.resize:
        return l10n.dimensionsValue(
          _activeResizeDimensions.width.round(),
          _activeResizeDimensions.height.round(),
        );
      case _SelectionOverlayFeedbackMode.none:
        return '';
    }
  }

  bool get _isFeedbackVisible =>
      (_feedbackMode != _SelectionOverlayFeedbackMode.none &&
          _feedbackMode != _SelectionOverlayFeedbackMode.translate) ||
      widget.isDrawing;

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
    required this.onEffectSelected,
  });
  final AppLocalizations l10n;
  final Future<void> Function(SelectionEffect effect, BuildContext context) onEffectSelected;

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
        color: AppColors.white,
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
                spacing: AppSpacing.medium,
                children: <Widget>[
                  AppSvgIcon(
                    icon: effect.icon,
                    size: AppLayout.iconSize,
                  ),
                  AppText(effectLabel(widget.l10n, effect)),
                ],
              ),
            ),
          )
          .toList(),
    ).then((final SelectionEffect? selected) {
      if (mounted && selected != null) {
        // ignore: use_build_context_synchronously
        widget.onEffectSelected(selected, context);
      }
    });
  }
}
