import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/image_painter.dart';
import 'package:fpaint/widgets/transparent_background.dart';

class LayerThumbnail extends StatelessWidget {
  const LayerThumbnail({
    super.key,
    required this.layer,
  });

  final Layer layer;

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.get(context);
    const int patternSize = 4;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Align to transparency pattern grid to ensure propre rendering of the transparency background
        final int size =
            (constraints.maxWidth / patternSize).floor() * patternSize;
        return SizedBox(
          width: size.toDouble(),
          height: size.toDouble(),
          child: FutureBuilder<ui.Image>(
            future: layer.getThumbnail(appModel.canvas.canvasSize),
            builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data != null) {
                return Stack(
                  children: [
                    const TransparentPaper(patternSize: patternSize),
                    SizedBox(
                      width: size.toDouble(),
                      height: size.toDouble(),
                      child: CustomPaint(
                        painter: ImagePainter(snapshot.data!),
                      ),
                    ),
                  ],
                );
              }
              return const TransparentPaper(patternSize: patternSize);
            },
          ),
        );
      },
    );
  }
}
