import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/container_slider.dart';
import 'package:fpaint/widgets/image_painter.dart';
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
    return Tooltip(
      margin: const EdgeInsets.only(left: 150),
      waitDuration: const Duration(milliseconds: 1000),
      message: '${layer.id}:"${layer.name}" Opacity: ${layer.opacity.toStringAsFixed(0)}',
      child: Container(
        margin: EdgeInsets.all(minimal ? 2 : 4),
        padding: EdgeInsets.all(minimal ? 2 : 8),
        decoration: BoxDecoration(
          color: minimal ? (layer.isVisible ? null : Colors.grey) : null,
          border: Border.all(
            color: layer.isSelected ? Colors.blue : Colors.grey.shade700,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: minimal
            ? Column(
                children: [
                  TruncatedTextWidget(text: layer.name, maxLength: 10),
                  Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      _buildThumbnailAndOpacity(appModel, layer),
                      if (!layer.isVisible) const Icon(Icons.visibility_off, color: Colors.red),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(layer.name),
                  ),
                  _buildThumbnailAndOpacity(appModel, layer),
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
      ),
    );
  }

  Widget _buildThumbnailAndOpacity(final AppModel appModel, final Layer layer) {
    return SizedBox(
      height: 60,
      width: 60,
      child: ContainerSlider(
        key: ValueKey(layer.name + layer.id),
        minValue: 0.0,
        maxValue: 100.0,
        initialValue: layer.opacity,
        onSlideStart: () {
          // appModel.update();
        },
        onChanged: (value) => layer.opacity = value,
        onChangeEnd: (value) {
          layer.opacity = value;
          appModel.update();
        },
        onSlideEnd: () => appModel.update(),
        child: LayerThumbnail(layer: layer),
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
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
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
