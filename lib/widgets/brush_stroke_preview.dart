import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/brush_grain.dart';
import 'package:fpaint/models/brush_hatch.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/models/hatch_pattern.dart';
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
    final Future<void>? pending = switch (widget.style) {
      BrushStyle.grain => BrushGrain.instance.prewarm(),
      BrushStyle.hatch => BrushHatch.instance.prewarm(const HatchPattern()),
      BrushStyle.crossHatch => BrushHatch.instance.prewarm(const HatchPattern(crossed: true)),
      _ => null,
    };
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
