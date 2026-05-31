import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/providers/shell_provider.dart';
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

typedef DuplicateMoveCallback = Future<void> Function(Offset offset, bool duplicateOnNewLayer);

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
    this.onDuplicateMove,
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
  final Future<void> Function() onCopy;

  /// A callback that is called when the selection rectangle is dragged.
  final void Function(Offset) onDrag;

  /// A callback that duplicates the selection (copy then paste).
  final Future<void> Function() onDuplicate;

  /// A callback that duplicates the selection and starts moving the duplicate.
  final DuplicateMoveCallback? onDuplicateMove;

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

const int _selectionModeButtonCount = AppMath.four;
const int _selectionQuickActionButtonCount = AppMath.four;
const double _selectionToolbarSurfacePadding = AppSpacing.small;

Offset _topLeft(final Rect b) => b.topLeft;
Offset _topRight(final Rect b) => b.topRight;
Offset _bottomLeft(final Rect b) => b.bottomLeft;
Offset _bottomRight(final Rect b) => b.bottomRight;
Offset _centerLeft(final Rect b) => Offset(b.left, b.center.dy);
Offset _centerRight(final Rect b) => Offset(b.right, b.center.dy);
Offset _centerTop(final Rect b) => Offset(b.center.dx, b.top);
Offset _centerBottom(final Rect b) => Offset(b.center.dx, b.bottom);

class _SelectionRectWidgetState extends State<SelectionRectWidget> with EscapeFocusMixin<SelectionRectWidget> {
  Size _activeResizeDimensions = Size.zero;
  double _activeRotationDegrees = 0;
  double _activeScalePercent = AppMath.percentScale;
  bool _duplicateMoveOnNewLayer = false;
  _SelectionOverlayFeedbackMode _feedbackMode = _SelectionOverlayFeedbackMode.none;
  bool _isDuplicateMovePending = false;
  Offset _pendingDuplicateMoveDelta = Offset.zero;
  @override
  Widget build(final BuildContext context) {
    if (widget.path1 == null) {
      return const SizedBox();
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ShellProvider? shellProvider = ShellProvider.maybeOf(context);
    final InteractionLayoutProfile interactionProfile =
        shellProvider?.interactionLayoutProfile ?? AppInteractionProfiles.mouse;
    final double modeToggleSize = interactionProfile.buttonSize;
    final double modeToggleSpacing = interactionProfile.buttonSpacing;
    final double handleSize = interactionProfile.dragHandleSize;
    final bool showQuickActions = widget.enableMoveAndResize && !widget.isDrawing;
    final Rect bounds = widget.path1!.getBounds();
    final double contextualToolbarWidth = _selectionToolbarWidth(
      buttonSize: modeToggleSize,
      spacing: modeToggleSpacing,
      showQuickActions: showQuickActions,
    );
    final double width = max(
      bounds.left + bounds.width + handleSize,
      bounds.center.dx + contextualToolbarWidth / AppMath.pair,
    );

    final double rotationOverhead = widget.enableMoveAndResize
        ? AppInteraction.selectionToolbarMargin + modeToggleSize
        : 0;
    final double height = bounds.bottom + bounds.height + handleSize + rotationOverhead;

    final List<Widget> stackChildren = <Widget>[
      AnimatedMarchingAntsPath(path: widget.path1!),
      if (widget.path2 != null) AnimatedMarchingAntsPath(path: widget.path2!),
      _buildModeControls(
        bounds,
        l10n,
        interactionProfile,
        showQuickActions: showQuickActions,
      ),
    ];

    if (widget.enableMoveAndResize) {
      stackChildren.add(
        OverlayDragHandle(
          position: bounds.center,
          size: handleSize,
          cursor: SystemMouseCursors.move,
          onPanStart: (final DragStartDetails _) => _beginTranslateFeedback(),
          onPanUpdate: (final DragUpdateDetails details) => _handleMoveDelta(details.delta),
          onPanEnd: _endFeedback,
          onPanCancel: _endFeedback,
        ),
      );

      for (final _HandleDescriptor desc in _resizeHandles) {
        stackChildren.add(
          OverlayDragHandle(
            position: desc.position(bounds),
            size: handleSize,
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

    return wrapWithEscapeFocus(
      child: SizedBox(
        width: width < 0 ? 0 : width,
        height: height < 0 ? 0 : height,
        child: Stack(children: stackChildren),
      ),
    );
  }

  @override
  void onEscapePressed() => widget.onCancel();
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
    _duplicateMoveOnNewLayer = false;
    _pendingDuplicateMoveDelta = Offset.zero;
    _isDuplicateMovePending = false;
    setState(() {
      _feedbackMode = _SelectionOverlayFeedbackMode.translate;
    });
  }

  /// Builds the contextual selection toolbar and feedback bubble.
  Widget _buildModeControls(
    final Rect bounds,
    final AppLocalizations l10n,
    final InteractionLayoutProfile interactionProfile, {
    required final bool showQuickActions,
  }) {
    final double buttonSize = interactionProfile.buttonSize;
    final double spacing = interactionProfile.buttonSpacing;
    final double iconSize = interactionProfile.iconSize;
    final double modeControlsWidth = _controlSurfaceWidth(
      contentWidth: _controlGroupContentWidth(
        buttonSize: buttonSize,
        spacing: spacing,
        buttonCount: _selectionModeButtonCount,
      ),
    );
    final double quickActionsWidth = _controlSurfaceWidth(
      contentWidth: _controlGroupContentWidth(
        buttonSize: buttonSize,
        spacing: spacing,
        buttonCount: _selectionQuickActionButtonCount,
      ),
    );
    final double controlsWidth = showQuickActions ? modeControlsWidth + spacing + quickActionsWidth : modeControlsWidth;
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double idealControlsTop = bounds.top - AppInteraction.selectionToolbarMargin - buttonSize / AppMath.pair;
    final double bottomControlsTop = bounds.bottom + AppInteraction.selectionToolbarMargin;
    final OverlayPlacement placement = computeOverlayPlacement(
      viewportHeight: viewportHeight,
      idealTop: idealControlsTop,
      bottomTop: bottomControlsTop,
      isFeedbackVisible: _isFeedbackVisible,
    );
    final double controlsLeft = bounds.center.dx - controlsWidth / AppMath.pair;
    final double modeButtonsLeft = controlsLeft + _selectionToolbarSurfacePadding;
    final double controlsTop = placement.controlsTop + _selectionToolbarSurfacePadding;
    final Offset scaleHandleCenter = Offset(
      modeButtonsLeft + buttonSize + spacing + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );
    final Offset rotateHandleCenter = Offset(
      modeButtonsLeft + (buttonSize + spacing) * AppMath.pair + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );

    final Widget feedbackBubble = buildOverlayFeedbackBubble(label: _feedbackLabel(l10n));
    final Widget modeButtons = buildOverlayControlSurface(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: spacing,
        children: <Widget>[
          buildOverlayModeButton(
            tooltip: l10n.translate,
            icon: AppIcon.move,
            size: buttonSize,
            iconSize: iconSize,
            isSelected: _feedbackMode == _SelectionOverlayFeedbackMode.translate,
            cursor: SystemMouseCursors.move,
            onPanStart: (final DragStartDetails _) => _beginTranslateFeedback(),
            onPanUpdate: (final DragUpdateDetails details) => _handleMoveDelta(details.delta),
            onPanEnd: (final DragEndDetails _) => _endFeedback(),
            onPanCancel: _endFeedback,
          ),
          buildOverlayModeButton(
            tooltip: l10n.scale,
            icon: AppIcon.openInFull,
            size: buttonSize,
            iconSize: iconSize,
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
            size: buttonSize,
            iconSize: iconSize,
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
            size: buttonSize,
            iconSize: iconSize,
            cursor: SystemMouseCursors.click,
            onTap: widget.onToggleTransformMode,
          ),
        ],
      ),
    );
    final Widget? quickActions = showQuickActions
        ? buildOverlayControlSurface(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: spacing,
              children: <Widget>[
                buildOverlayCircleButton(
                  tooltip: l10n.copyToClipboard,
                  icon: AppIcon.clipboardCopy,
                  contentSemantic: AppButtonContentSemantic.enabled,
                  cursor: SystemMouseCursors.click,
                  showBorder: false,
                  size: buttonSize,
                  iconSize: iconSize,
                  onTap: () => _handleCopy(l10n),
                ),
                buildOverlayCircleButton(
                  tooltip: l10n.duplicate,
                  icon: AppIcon.copy,
                  contentSemantic: AppButtonContentSemantic.enabled,
                  cursor: SystemMouseCursors.click,
                  size: buttonSize,
                  showBorder: false,
                  iconSize: iconSize,
                  onTap: _handleDuplicate,
                ),
                _EffectsPopupButton(
                  l10n: l10n,
                  buttonSize: buttonSize,
                  iconSize: iconSize,
                  onEffectSelected: widget.onEffectSelected,
                ),
                buildOverlayCircleButton(
                  tooltip: l10n.cancel,
                  icon: AppIcon.selectorCancel,
                  contentSemantic: AppButtonContentSemantic.dangerous,
                  cursor: SystemMouseCursors.click,
                  showBorder: false,
                  size: buttonSize,
                  iconSize: iconSize,
                  onTap: widget.onCancel,
                ),
              ],
            ),
          )
        : null;

    return buildPositionedOverlayControls(
      left: controlsLeft,
      placement: placement,
      spacing: spacing,
      controlGroups: <Widget>[modeButtons, ?quickActions],
      isFeedbackVisible: _isFeedbackVisible,
      feedbackBubble: feedbackBubble,
    );
  }

  /// Returns the width of one toolbar group's button content.
  double _controlGroupContentWidth({
    required final double buttonSize,
    required final double spacing,
    required final int buttonCount,
  }) {
    final int gapCount = max(AppMath.zero, buttonCount - AppMath.one);
    return (buttonSize * buttonCount) + (spacing * gapCount);
  }

  /// Returns the full grouped-surface width after adding shared panel padding.
  double _controlSurfaceWidth({required final double contentWidth}) {
    return contentWidth + (_selectionToolbarSurfacePadding * AppMath.pair);
  }

  bool get _duplicateMoveCreatesNewLayer {
    return HardwareKeyboard.instance.isShiftPressed;
  }

  /// Clears any transient drag state and hides the current feedback bubble.
  void _endFeedback() {
    _duplicateMoveOnNewLayer = false;
    _pendingDuplicateMoveDelta = Offset.zero;
    _isDuplicateMovePending = false;
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

  /// Drains queued modifier-assisted move deltas into the duplicate-move
  /// callback so the selection only duplicates once per drag gesture.
  Future<void> _flushDuplicateMove() async {
    try {
      while (_pendingDuplicateMoveDelta != Offset.zero) {
        final Offset moveDelta = _pendingDuplicateMoveDelta;
        _pendingDuplicateMoveDelta = Offset.zero;
        await widget.onDuplicateMove!(moveDelta, _duplicateMoveOnNewLayer);
        if (!mounted) {
          return;
        }
      }
    } finally {
      _isDuplicateMovePending = false;
    }
  }

  /// Executes the copy action and confirms it with a transient snackbar.
  Future<void> _handleCopy(final AppLocalizations l10n) async {
    await widget.onCopy();
    if (!mounted) {
      return;
    }
    context.showSnackBarMessage(l10n.copied);
  }

  /// Executes the duplicate action.
  Future<void> _handleDuplicate() async {
    await widget.onDuplicate();
  }

  /// Routes move deltas either to marquee translation or, when the platform
  /// duplicate modifier is held, to the duplicate-and-move handoff callback.
  void _handleMoveDelta(final Offset delta) {
    if (_shouldDuplicateMoveGesture) {
      if (!_isDuplicateMovePending && _pendingDuplicateMoveDelta == Offset.zero) {
        _duplicateMoveOnNewLayer = _duplicateMoveCreatesNewLayer;
      }
      _pendingDuplicateMoveDelta += delta;
      if (_isDuplicateMovePending) {
        return;
      }
      _isDuplicateMovePending = true;
      unawaited(_flushDuplicateMove());
      return;
    }

    widget.onDrag(delta);
    _updateResizeFeedback();
  }

  bool get _isApplePlatform {
    return defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _isFeedbackVisible =>
      (_feedbackMode != _SelectionOverlayFeedbackMode.none &&
          _feedbackMode != _SelectionOverlayFeedbackMode.translate) ||
      widget.isDrawing;

  /// Returns the total width of the contextual toolbar for the current state.
  double _selectionToolbarWidth({
    required final double buttonSize,
    required final double spacing,
    required final bool showQuickActions,
  }) {
    final double modeControlsWidth = _controlSurfaceWidth(
      contentWidth: _controlGroupContentWidth(
        buttonSize: buttonSize,
        spacing: spacing,
        buttonCount: _selectionModeButtonCount,
      ),
    );
    if (!showQuickActions) {
      return modeControlsWidth;
    }

    final double quickActionsWidth = _controlSurfaceWidth(
      contentWidth: _controlGroupContentWidth(
        buttonSize: buttonSize,
        spacing: spacing,
        buttonCount: _selectionQuickActionButtonCount,
      ),
    );
    return modeControlsWidth + spacing + quickActionsWidth;
  }

  bool get _shouldDuplicateMoveGesture {
    if (widget.onDuplicateMove == null) {
      return false;
    }
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    return _isApplePlatform ? keyboard.isAltPressed : keyboard.isControlPressed;
  }

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
    required this.buttonSize,
    required this.iconSize,
    required this.onEffectSelected,
  });
  final double buttonSize;
  final double iconSize;
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
      icon: AppIcon.autoFixHigh,
      showBorder: false,
      contentSemantic: AppButtonContentSemantic.enabled,
      cursor: SystemMouseCursors.click,
      size: widget.buttonSize,
      iconSize: widget.iconSize,
      onTap: () => _showEffectsMenu(context),
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
