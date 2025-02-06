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
    return FutureBuilder<ui.Image>(
      future: layer.getThumbnail(appModel.canvas.canvasSize),
      builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return SizedBox(
            width: 50,
            height: 50,
            child: snapshot.data == null
                ? const SizedBox(
                    width: 50,
                    height: 50,
                    child: TransparentPaper(patternSize: 4),
                  )
                : CustomPaint(
                    painter: ImagePainter(snapshot.data!),
                  ),
          );
        } else if (snapshot.hasError) {
          return Container(
            width: 50,
            height: 50,
            color: Colors.red,
            child: const Center(
              child: Icon(Icons.error, color: Colors.white),
            ),
          );
        }
        return const SizedBox(
          width: 50,
          height: 50,
        );
      },
    );
  }
}
