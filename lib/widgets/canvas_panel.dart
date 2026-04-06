import 'package:flutter/material.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/canvas_panel_painter.dart';

/// A widget that displays the canvas panel.
class CanvasPanel extends StatelessWidget {
  const CanvasPanel({super.key});

  @override
  Widget build(final BuildContext context) {
    final LayersProvider layers = LayersProvider.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: CanvasPanelPainter(
        layers.list,
        layers.size,
        includeTransparentBackground: true,
      ),
    );
  }
}
