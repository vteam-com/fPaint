import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/transparent_background.dart';
import 'package:fpaint/widgets/truncated_text.dart';

class LayerSelector extends StatelessWidget {
  const LayerSelector({
    super.key,
    required this.context,
    required this.layer,
    required this.minimal,
    required this.showDelete,
  });

  final BuildContext context;
  final Layer layer;
  final bool showDelete;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.get(context);
    return Container(
      margin: EdgeInsets.all(minimal ? 2 : 4),
      padding: EdgeInsets.all(minimal ? 2 : 8),
      decoration: BoxDecoration(
        color: minimal ? (layer.isVisible ? null : Colors.grey) : null,
        border: Border.all(
          color: layer.isSelected ? Colors.blue : Colors.grey.shade300,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: minimal
          ? Column(
              children: [
                TruncatedTextWidget(text: layer.name, maxLength: 10),
                LayerThumbnail(layer: layer),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(layer.name),
                ),
                Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: LayerThumbnail(layer: layer),
                ),
                IconButton(
                  icon: Icon(
                    layer.isVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => appModel.toggleLayerVisibility(layer),
                ),
                if (showDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => appModel.removeLayer(layer),
                  ),
              ],
            ),
    );
  }
}

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
      future: layer.getThumbnail(appModel.canvasSize),
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

class ImagePainter extends CustomPainter {
  ImagePainter(this.image);
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Calculate the scale factors to fit the image into the destination rectangle
    final double scaleX = size.width / image.width;
    final double scaleY = size.height / image.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate the dimensions of the scaled image
    final double scaledWidth = image.width * scale;
    final double scaledHeight = image.height * scale;

    // Center the image within the destination rectangle
    final double dx = (size.width - scaledWidth) / 2;
    final double dy = (size.height - scaledHeight) / 2;

    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);

    // Draw the image
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
