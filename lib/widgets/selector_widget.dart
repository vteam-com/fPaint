import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/marching_ants_path.dart';
import 'package:fpaint/widgets/svg_icon.dart';

const String _selectorCoordinatesFormat = '{x}\n{y}';
const String _placeholderX = '{x}';
const String _placeholderY = '{y}';

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
    required this.isTransformMode,
    required this.onDrag,
    required this.onResize,
    required this.onRotate,
    required this.onToggleTransformMode,
    this.enableMoveAndResize = true,
  });

  /// Whether the selection rectangle can be moved and resized.
  final bool enableMoveAndResize;

  /// Whether the selection is currently in perspective/skew transform mode.
  final bool isTransformMode;

  /// A callback that is called when the selection rectangle is dragged.
  final void Function(Offset) onDrag;

  /// A callback that is called when the selection rectangle is resized.
  final void Function(NineGridHandle, Offset) onResize;

  /// A callback that is called when the selection is rotated by [angleRadians].
  final void Function(double angleRadians) onRotate;

  /// A callback that toggles between resize/rotate and perspective/skew modes.
  final VoidCallback onToggleTransformMode;

  /// The primary path of the selection rectangle.
  final Path? path1;

  /// An optional secondary path for the selection rectangle.
  final Path? path2;
  @override
  State<SelectionRectWidget> createState() => _SelectionRectWidgetState();
}

const int defaultHandleSize = AppInteraction.selectionHandleSize;

class _SelectionRectWidgetState extends State<SelectionRectWidget> {
  bool showCoordinate = false;
  @override
  Widget build(final BuildContext context) {
    if (widget.path1 == null) {
      return const SizedBox();
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Rect bounds = widget.path1!.getBounds();
    final double modeToggleSize = AppInteraction.imagePlacementButtonSize;
    final double modeToggleSpacing = AppInteraction.imagePlacementButtonSpacing;
    final double width = max(
      bounds.left + bounds.width + defaultHandleSize,
      bounds.center.dx + modeToggleSize + modeToggleSpacing + modeToggleSize,
    );

    // Extra space above for the rotation handle stem + handle
    final double rotationOverhead = widget.enableMoveAndResize
        ? AppInteraction.rotationHandleDistance + modeToggleSize
        : 0;
    final double height = bounds.bottom + bounds.height + defaultHandleSize + rotationOverhead;

    final List<Widget> stackChildren = <Widget>[
      if (!widget.isTransformMode) AnimatedMarchingAntsPath(path: widget.path1!),
      if (!widget.isTransformMode && widget.path2 != null) AnimatedMarchingAntsPath(path: widget.path2!),
      _buildRotateModeControl(bounds, l10n),
      _buildTransformModeControl(bounds, l10n),
    ];

    if (widget.enableMoveAndResize && !widget.isTransformMode) {
      stackChildren.addAll(<Widget>[
        // Center handle for moving
        _buildHandle(
          position: bounds.center,
          cursor: SystemMouseCursors.move,
          onPanUpdate: (final DragUpdateDetails details) => widget.onDrag(
            details.delta,
          ),
        ),

        // Top Left
        _buildHandle(
          position: bounds.topLeft,
          cursor: SystemMouseCursors.resizeUpLeft,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.topLeft,
            details.delta,
          ),
        ),

        // Top Right
        _buildHandle(
          position: bounds.topRight,
          cursor: SystemMouseCursors.resizeUpRight,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.topRight,
            details.delta,
          ),
        ),

        // Bottom Left
        _buildHandle(
          position: bounds.bottomLeft,
          cursor: SystemMouseCursors.resizeDownLeft,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.bottomLeft,
            details.delta,
          ),
        ),

        // Bottom right
        _buildHandle(
          position: bounds.bottomRight,
          cursor: SystemMouseCursors.resizeDownRight,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.bottomRight,
            details.delta,
          ),
        ),

        // Side Left
        _buildHandle(
          position: Offset(
            bounds.left,
            bounds.center.dy,
          ),
          cursor: SystemMouseCursors.resizeLeft,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.left,
            details.delta,
          ),
        ),

        // Side Right
        _buildHandle(
          position: Offset(
            bounds.right,
            bounds.center.dy,
          ),
          cursor: SystemMouseCursors.resizeRight,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.right,
            details.delta,
          ),
        ),

        // Center Top
        _buildHandle(
          position: Offset(
            bounds.center.dx,
            bounds.top,
          ),
          cursor: SystemMouseCursors.resizeUp,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.top,
            details.delta,
          ),
        ),

        // Center Bottom
        _buildHandle(
          position: Offset(
            bounds.center.dx,
            bounds.bottom,
          ),
          cursor: SystemMouseCursors.resizeDown,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.bottom,
            details.delta,
          ),
        ),
      ]);
    }

    return SizedBox(
      width: width < 0 ? 0 : width,
      height: height < 0 ? 0 : height,
      child: Stack(children: stackChildren),
    );
  }

  /// Builds a handle for resizing or moving the selection rectangle.
  ///
  /// The [position] parameter specifies the position of the handle.
  /// The [cursor] parameter specifies the cursor to display when the mouse is over the handle.
  /// The [onPanUpdate] parameter is a callback that is called when the handle is dragged.
  Widget _buildHandle({
    required final Offset position,
    required final MouseCursor cursor,
    required final void Function(DragUpdateDetails) onPanUpdate,
  }) {
    final int handleSize = (showCoordinate ? (defaultHandleSize * AppVisual.previewTextScale) : defaultHandleSize)
        .toInt();

    return Positioned(
      left: position.dx - (handleSize / AppMath.pair),
      top: position.dy - (handleSize / AppMath.pair),
      child: GestureDetector(
        onPanUpdate: (final DragUpdateDetails details) {
          setState(() {
            showCoordinate = true;
          });
          onPanUpdate(details);
        },
        onPanEnd: (final DragEndDetails _) => setState(() => showCoordinate = false),
        child: MouseRegion(
          cursor: cursor,
          child: Container(
            width: handleSize.toDouble(),
            height: handleSize.toDouble(),
            decoration: BoxDecoration(
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: AppStroke.regular),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: showCoordinate
                ? Center(
                    child: Text(
                      _selectorCoordinatesFormat
                          .replaceFirst(_placeholderX, position.dx.toInt().toString())
                          .replaceFirst(_placeholderY, position.dy.toInt().toString()),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: AppSpacing.sm, color: Colors.white),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  /// Builds the rotate/resize mode control above the selection.
  ///
  /// When transform mode is inactive, dragging this control rotates the
  /// selection around its center. When transform mode is active, tapping it
  /// switches back to rotate/resize mode.
  Widget _buildRotateModeControl(
    final Rect bounds,
    final AppLocalizations l10n,
  ) {
    final double handleSize = AppInteraction.imagePlacementButtonSize;
    final Offset handleCenter = Offset(
      bounds.center.dx,
      bounds.top - AppInteraction.rotationHandleDistance,
    );

    return Positioned(
      left: handleCenter.dx - (handleSize / AppMath.pair),
      top: handleCenter.dy - (handleSize / AppMath.pair),
      child: Tooltip(
        message: l10n.resizeRotate,
        child: GestureDetector(
          onTap: widget.isTransformMode ? widget.onToggleTransformMode : null,
          onPanUpdate: widget.isTransformMode
              ? null
              : (final DragUpdateDetails details) {
                  final Offset pointer = handleCenter + details.delta;
                  final double previousAngle = atan2(
                    handleCenter.dy - bounds.center.dy,
                    handleCenter.dx - bounds.center.dx,
                  );
                  final double currentAngle = atan2(
                    pointer.dy - bounds.center.dy,
                    pointer.dx - bounds.center.dx,
                  );
                  widget.onRotate(currentAngle - previousAngle);
                },
          child: MouseRegion(
            cursor: widget.isTransformMode ? SystemMouseCursors.click : SystemMouseCursors.grab,
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: Colors.green,
                border: Border.all(color: Colors.white, width: AppStroke.regular),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rotate_right,
                size: AppLayout.iconSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransformModeControl(
    final Rect bounds,
    final AppLocalizations l10n,
  ) {
    final double handleSize = AppInteraction.imagePlacementButtonSize;
    final Offset toggleCenter = Offset(
      bounds.center.dx + handleSize + AppInteraction.imagePlacementButtonSpacing,
      bounds.top - AppInteraction.rotationHandleDistance,
    );

    return Positioned(
      left: toggleCenter.dx - (handleSize / AppMath.pair),
      top: toggleCenter.dy - (handleSize / AppMath.pair),
      child: Tooltip(
        message: l10n.transform,
        child: GestureDetector(
          onTap: widget.isTransformMode ? null : widget.onToggleTransformMode,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: AppColors.transformCornerHandle,
                border: Border.all(color: Colors.white, width: AppStroke.regular),
                shape: BoxShape.circle,
              ),
              child: iconFromSvgAsset(AppAssets.transformIcon),
            ),
          ),
        ),
      ),
    );
  }
}
