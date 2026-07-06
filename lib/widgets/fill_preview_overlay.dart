import 'package:flutter/widgets.dart';
import 'package:fpaint/models/render_helper.dart';
import 'package:fpaint/models/user_action_drawing.dart';

/// Paints the live paint-bucket preview — the held [action]'s region filled with
/// its solid colour / gradient / halftone — as a lightweight canvas overlay,
/// transformed into screen space by [canvasOffset] and [scale].
///
/// It reuses the exact [renderRegion] the committed fill uses (so the preview is
/// pixel-identical) but draws only the region path: cost is O(region path), never
/// a full-canvas re-composite. The fill is not on the layer until committed, so
/// dragging the tolerance just repaints this overlay.
class FillPreviewOverlay extends StatelessWidget {
  const FillPreviewOverlay({
    super.key,
    required this.action,
    required this.canvasOffset,
    required this.scale,
  });

  /// The held preview action (region path + fill colour / gradient / halftone).
  final UserActionDrawing action;

  /// Canvas-to-screen translation.
  final Offset canvasOffset;

  /// Canvas-to-screen scale.
  final double scale;

  @override
  Widget build(final BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FillPreviewPainter(action: action, canvasOffset: canvasOffset, scale: scale),
      ),
    );
  }
}

class _FillPreviewPainter extends CustomPainter {
  _FillPreviewPainter({
    required this.action,
    required this.canvasOffset,
    required this.scale,
  });

  final UserActionDrawing action;
  final Offset canvasOffset;
  final double scale;

  @override
  void paint(final Canvas canvas, final Size size) {
    final Path? path = action.path;
    if (path == null) {
      return;
    }
    canvas.save();
    canvas.translate(canvasOffset.dx, canvasOffset.dy);
    canvas.scale(scale);
    // Clip to the active selection, matching how the committed fill is rendered.
    final Path? clip = action.clipPath;
    if (clip != null) {
      canvas.clipPath(clip, doAntiAlias: true);
    }
    renderRegion(canvas, path, action.fillColor, action.gradient, action.halftoneFill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant final _FillPreviewPainter oldDelegate) {
    return oldDelegate.action != action || oldDelegate.canvasOffset != canvasOffset || oldDelegate.scale != scale;
  }
}
