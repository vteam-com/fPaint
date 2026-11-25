import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/models/render_helper.dart';

/// Paints a sample S-curve stroke with the real brush renderer, so the preview
/// is exactly what the brush lays down on the canvas.
class BrushStrokePreview extends StatefulWidget {
  /// Creates a [BrushStrokePreview].
  const BrushStrokePreview({
    super.key,
    required this.style,
    required this.brushSize,
  });

  /// Brush size used for the sample stroke.
  final double brushSize;

  /// The style to draw.
  final BrushStyle style;

  @override
  State<BrushStrokePreview> createState() => _BrushStrokePreviewState();
}

class _BrushStrokePreviewState extends State<BrushStrokePreview> {
  @override
  void initState() {
    super.initState();
    _prewarmTextures();
  }

  @override
  void didUpdateWidget(covariant BrushStrokePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) {
      _prewarmTextures();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BrushStrokePreviewPainter(style: widget.style, brushSize: widget.brushSize),
    );
  }

  /// Grain and hatch styles sample async-generated tiles; repaint once ready so
  /// the preview shows the texture instead of the solid fallback.
  void _prewarmTextures() {
    final Future<void>? pending = prewarmBrushStyleTextures(widget.style);
    pending?.then((void _) {
      if (mounted) {
        setState(() {});
      }
    });
  }
}

class _BrushStrokePreviewPainter extends CustomPainter {
  _BrushStrokePreviewPainter({required this.style, required this.brushSize});

  final double brushSize;
  final BrushStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = brushPreviewPath(size);
    final Paint paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = brushSize
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    drawPathWithBrushStyle(canvas, paint, path, style, brushSize);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrushStrokePreviewPainter oldDelegate) => true;
}

/// Builds the sample S-curve stroke that fills a preview of [size].
Path brushPreviewPath(Size size) {
  final double inset = size.width * AppBrushLibrary.previewInsetFraction;
  final double span = size.width - inset * AppMath.pair;
  final double midY = size.height / AppMath.pair;
  final double amplitude = size.height * AppBrushLibrary.previewAmplitudeFraction;
  final Path path = Path()..moveTo(inset, midY);
  for (int i = AppMath.one; i <= AppBrushLibrary.previewSegments; i++) {
    final double t = i / AppBrushLibrary.previewSegments;
    final double angle = t * AppBrushLibrary.previewWavePeriods * AppMath.pair * math.pi;
    path.lineTo(inset + span * t, midY - math.sin(angle) * amplitude);
  }
  return path;
}

/// The shared tap target for brush-preview controls (library tile, inline
/// swatch): an accessible button that hit-tests its whole box.
class BrushPreviewTapTarget extends StatelessWidget {
  /// Creates a [BrushPreviewTapTarget].
  const BrushPreviewTapTarget({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.isSelected = false,
  });

  /// The visual content.
  final Widget child;

  /// Whether the control is announced as selected.
  final bool isSelected;

  /// Accessible name of the control.
  final String label;

  /// Called when tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
