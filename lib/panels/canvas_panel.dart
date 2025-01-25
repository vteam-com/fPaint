import 'package:flutter/material.dart';
import 'package:fpaint/widgets/transparent_background.dart';

import '../models/app_model.dart';

class CanvasPanel extends StatelessWidget {
  const CanvasPanel({super.key, required this.appModel});
  final AppModel appModel;

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: CanvasPanelPainter(appModel),
    );
  }
}

class CanvasPanelPainter extends CustomPainter {
  CanvasPanelPainter(this._appModel);
  final AppModel _appModel;

  @override
  void paint(final Canvas canvas, final Size size) {
    /// Render the transparent grid
    drawTransaparentBackgroundOffsetAndSize(
      canvas,
      Offset.zero,
      _appModel.canvasSize,
    );

    for (final Layer layer in _appModel.layers.list.reversed) {
      if (layer.isVisible) {
        renderLayer(layer, canvas);
      }
    }
  }

  @override
  bool shouldRepaint(CanvasPanelPainter oldDelegate) => true;
}
