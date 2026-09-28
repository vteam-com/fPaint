import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';

/// Procreate-style vertical brush-size slider pinned to the canvas edge.
///
/// Works the same for touch, pen, mouse and trackpad: drag up to grow the
/// brush, down to shrink it. The scale is logarithmic so small brushes get as
/// much travel as large ones, and sliding the finger sideways away from the
/// track while dragging slows the change for fine control. While dragging, a
/// numeric readout rides beside the thumb and the canvas shows the brush-size
/// ring at the true zoomed diameter.
class BrushSizeEdgeSlider extends StatefulWidget {
  /// Creates a [BrushSizeEdgeSlider] driving [appProvider]'s brush size, sized
  /// for the active [interactionProfile].
  const BrushSizeEdgeSlider({
    super.key,
    required this.appProvider,
    required this.interactionProfile,
  });

  /// The provider whose armed tool's brush size the slider reads and writes.
  final AppProvider appProvider;

  /// Sizing for the dominant input modality (bigger for touch).
  final InteractionLayoutProfile interactionProfile;

  @override
  State<BrushSizeEdgeSlider> createState() => _BrushSizeEdgeSliderState();
}

class _BrushSizeEdgeSliderState extends State<BrushSizeEdgeSlider> {
  /// The continuous slider position while a drag is in progress, or null when
  /// idle (the position is then read from the brush size).
  double? _dragFraction;

  /// Horizontal pointer position where the drag started, the origin of the
  /// fine-scrub distance.
  double _dragStartDx = AppMath.zero.toDouble();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = widget.interactionProfile.buttonSize;
        final double thumbSize = widget.interactionProfile.dragHandleSize;
        final double trackLength = math.min(
          constraints.maxHeight * AppLayout.brushSizeEdgeSliderHeightFraction,
          AppLayout.brushSizeEdgeSliderMaxLength,
        );
        final double travel = trackLength - thumbSize;
        if (travel <= AppMath.zero) {
          return const SizedBox.shrink();
        }

        final double fraction = _dragFraction ?? widget.appProvider.brushSizeSliderFraction;
        final double thumbCenterY = thumbSize / AppMath.pair + travel * (AppMath.one - fraction);
        final String sizeLabel = widget.appProvider.brushSize.toStringAsFixed(AppMath.one);

        return Align(
          alignment: Alignment.centerLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Semantics(
                slider: true,
                label: context.l10n.brushSize,
                value: sizeLabel,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: GestureDetector(
                    key: Keys.brushSizeEdgeSlider,
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (DragStartDetails details) => _onDragStart(details, fraction),
                    onPanUpdate: (DragUpdateDetails details) => _onDragUpdate(details, travel),
                    onPanEnd: (DragEndDetails _) => _onDragEnd(),
                    onPanCancel: _onDragEnd,
                    child: SizedBox(
                      width: width,
                      height: trackLength,
                      child: CustomPaint(
                        painter: _BrushSizeEdgeSliderPainter(
                          fraction: fraction,
                          thumbSize: thumbSize,
                          isDragging: _dragFraction != null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_dragFraction != null)
                Positioned(
                  left: width + AppSpacing.medium,
                  top: thumbCenterY,
                  child: IgnorePointer(
                    child: FractionalTranslation(
                      translation: const Offset(0, -AppVisual.half),
                      child: KeyedSubtree(
                        key: Keys.brushSizeEdgeSliderReadout,
                        child: buildOverlayFeedbackBubble(label: sizeLabel),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _onDragEnd() {
    if (_dragFraction == null) {
      return;
    }
    setState(() {
      _dragFraction = null;
    });
  }

  void _onDragStart(DragStartDetails details, double fraction) {
    setState(() {
      _dragFraction = fraction;
      _dragStartDx = details.localPosition.dx;
    });
  }

  /// Moves the slider by the vertical drag [details] over a track of [travel]
  /// pixels, slowed by how far the pointer has strayed sideways from where the
  /// drag started.
  void _onDragUpdate(DragUpdateDetails details, double travel) {
    final double? current = _dragFraction;
    if (current == null) {
      return;
    }
    final double strayDistance = (details.localPosition.dx - _dragStartDx).abs();
    final double sensitivity =
        AppMath.one / (AppMath.one + strayDistance / AppInteraction.brushSizeEdgeSliderFineScrubPixels);
    final double next = (current - details.delta.dy / travel * sensitivity).clamp(
      AppMath.zero.toDouble(),
      AppMath.one.toDouble(),
    );
    setState(() {
      _dragFraction = next;
    });
    widget.appProvider.applyBrushSizeSliderFraction(next);
  }
}

/// Paints the edge slider: a translucent pill, a groove filled from the bottom
/// up to the current size, and a round thumb.
class _BrushSizeEdgeSliderPainter extends CustomPainter {
  const _BrushSizeEdgeSliderPainter({
    required this.fraction,
    required this.thumbSize,
    required this.isDragging,
  });

  /// Slider position, 0 (smallest brush, bottom) to 1 (largest, top).
  final double fraction;

  /// Diameter of the round thumb.
  final double thumbSize;

  /// Whether a drag is in progress, which highlights the thumb.
  final bool isDragging;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / AppMath.pair;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      Paint()..color = AppColors.scrim,
    );

    final double centerX = size.width / AppMath.pair;
    final double halfThumb = thumbSize / AppMath.pair;
    final double top = halfThumb;
    final double bottom = size.height - halfThumb;
    final double thumbY = bottom - (bottom - top) * fraction;
    const Radius grooveRadius = Radius.circular(AppLayout.brushSizeEdgeSliderTrackWidth / AppMath.pair);
    const double halfGroove = AppLayout.brushSizeEdgeSliderTrackWidth / AppMath.pair;

    canvas.drawRRect(
      RRect.fromLTRBR(centerX - halfGroove, top, centerX + halfGroove, bottom, grooveRadius),
      Paint()..color = AppColors.overlayBorder,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(centerX - halfGroove, thumbY, centerX + halfGroove, bottom, grooveRadius),
      Paint()..color = AppColors.primary,
    );

    final Offset thumbCenter = Offset(centerX, thumbY);
    canvas.drawCircle(
      thumbCenter,
      halfThumb,
      Paint()..color = isDragging ? AppColors.accent : AppColors.white,
    );
    canvas.drawCircle(
      thumbCenter,
      halfThumb,
      Paint()
        ..color = AppColors.overlayDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.thin,
    );
  }

  @override
  bool shouldRepaint(covariant _BrushSizeEdgeSliderPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.thumbSize != thumbSize ||
        oldDelegate.isDragging != isDragging;
  }
}
