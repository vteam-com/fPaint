import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/transparent_background.dart';

class CanvasPanel extends StatelessWidget {
  const CanvasPanel({super.key, required this.appModel});
  final AppModel appModel;

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: CanvasPanelPainter(appModel, includeTransparentBackground: true),
    );
  }
}

class CanvasPanelPainter extends CustomPainter {
  CanvasPanelPainter(
    this._appModel, {
    this.includeTransparentBackground = false,
  });
  final AppModel _appModel;
  final bool includeTransparentBackground;

  @override
  void paint(final Canvas canvas, final Size size) {
    canvas.scale(_appModel.canvas.scale);

    /// Render the transparent grid
    if (includeTransparentBackground) {
      drawTransaparentBackgroundOffsetAndSize(
        canvas,
        Offset.zero,
        _appModel.canvas.size,
      );
    }

    for (final Layer layer in _appModel.layers.list.reversed) {
      if (layer.isVisible) {
        layer.renderLayer(canvas);
      }
    }
  }

  @override
  bool shouldRepaint(CanvasPanelPainter oldDelegate) => true;
}
