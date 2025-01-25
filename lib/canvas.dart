import 'package:flutter/material.dart';
import 'package:fpaint/widgets/transparent_background.dart';

import 'models/app_model.dart';

class MyCanvas extends StatelessWidget {
  const MyCanvas({super.key, required this.appModel});
  final AppModel appModel;

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: MyCanvasPainter(appModel),
    );
  }
}

class MyCanvasPainter extends CustomPainter {
  MyCanvasPainter(this._appModel);
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
  bool shouldRepaint(MyCanvasPainter oldDelegate) => true;
}
