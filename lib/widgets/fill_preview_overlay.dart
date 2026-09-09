import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/models/render_helper.dart';
import 'package:fpaint/models/user_action_drawing.dart';

/// Paints the live paint-bucket preview — the held [action]'s region filled with
/// its solid colour / gradient / halftone — as a lightweight canvas overlay,
/// transformed into screen space by [viewport].
///
/// It reuses the exact [renderRegion] the committed fill uses (so the preview is
/// pixel-identical) but draws only the region path: cost is O(region path), never
/// a full-canvas re-composite. The fill is not on the layer until committed, so
/// dragging the tolerance just repaints this overlay.
class FillPreviewOverlay extends StatelessWidget {
  const FillPreviewOverlay({
    super.key,
    required this.action,
    required this.viewport,
  });

  /// The held preview action (region path + fill colour / gradient / halftone).
  final UserActionDrawing action;

  /// The canvas-to-screen viewport transform (pan, zoom and rotation).
  final ViewportTransform viewport;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FillPreviewPainter(action: action, viewport: viewport),
      ),
    );
  }
}

class _FillPreviewPainter extends CustomPainter {
  _FillPreviewPainter({
    required this.action,
    required this.viewport,
  });

  final UserActionDrawing action;
  final ViewportTransform viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final Path? path = action.path;
    if (path == null) {
      return;
    }
    canvas.save();
    canvas.transform(viewport.matrix.storage);
    // Clip to the active selection, matching how the committed fill is rendered.
    final Path? clip = action.clipPath;
    if (clip != null) {
      canvas.clipPath(clip, doAntiAlias: true);
    }
    renderRegion(
      canvas,
      path,
      action.fillColor,
      action.gradient,
      action.halftoneFill,
      hatchPattern: action.hatchPattern,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FillPreviewPainter oldDelegate) {
    return oldDelegate.action != action || oldDelegate.viewport != viewport;
  }
}
