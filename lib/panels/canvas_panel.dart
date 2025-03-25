import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/transparent_background.dart';

class CanvasPanel extends StatelessWidget {
  const CanvasPanel({super.key});

  @override
  Widget build(final BuildContext context) {
    final LayersProvider layers = LayersProvider.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: CanvasPanelPainter(layers, includeTransparentBackground: true),
    );
  }
}

class CanvasPanelPainter extends CustomPainter {
  CanvasPanelPainter(
    this._layers, {
    this.includeTransparentBackground = false,
  });
  final LayersProvider _layers;
  final bool includeTransparentBackground;

  @override
  void paint(final Canvas canvas, final Size size) {
    // Create a PictureRecorder to record the painting commands
    final PictureRecorder recorder = PictureRecorder();
    final Canvas recordingCanvas = Canvas(
      recorder,
      Rect.fromPoints(Offset.zero, Offset(size.width, size.height)),
    );

    // Render the transparent grid on the recording canvas
    if (includeTransparentBackground) {
      drawTransaparentBackgroundOffsetAndSize(
        canvas: recordingCanvas,
        size: _layers.size,
      );
    }

    // Render the layers on the recording canvas
    for (final LayerProvider layer in _layers.list.reversed) {
      if (layer.isVisible) {
        layer.renderLayer(recordingCanvas);
      }
    }

    // End recording and create an image
    final ui.Picture picture = recorder.endRecording();
    final ui.Image uiImage =
        picture.toImageSync(size.width.toInt(), size.height.toInt());

    // Draw the cached image on the original canvas
    canvas.drawImage(uiImage, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(final CanvasPanelPainter oldDelegate) => true;
}
