import 'package:flutter/material.dart';
import 'package:fpaint/providers/layer_provider.dart';
import 'package:fpaint/widgets/image_painter.dart';
import 'package:fpaint/widgets/transparent_background.dart';

class LayerThumbnail extends StatelessWidget {
  const LayerThumbnail({
    super.key,
    required this.layer,
  });

  final LayerProvider layer;

  @override
  Widget build(BuildContext context) {
    const int patternSize = 4;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Align to transparency pattern grid to ensure propre rendering of the transparency background
        final int size =
            (constraints.maxWidth / patternSize).floor() * patternSize;

        return SizedBox(
          width: size.toDouble(),
          height: size.toDouble(),
          child: Stack(
            children: [
              const TransparentPaper(patternSize: patternSize),
              if (layer.thumbnailImage != null)
                SizedBox(
                  width: size.toDouble(),
                  height: size.toDouble(),
                  child: CustomPaint(
                    painter: ImagePainter(layer.thumbnailImage!),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
