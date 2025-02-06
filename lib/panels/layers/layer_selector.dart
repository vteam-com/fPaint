import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/layers/blend_mode.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/widgets/container_slider.dart';
import 'package:fpaint/widgets/truncated_text.dart';

class LayerSelector extends StatelessWidget {
  const LayerSelector({
    super.key,
    required this.context,
    required this.layer,
    required this.minimal,
    required this.isSelected,
    required this.showDelete,
  });

  final BuildContext context;
  final Layer layer;
  final bool showDelete;
  final bool minimal;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.get(context);
    return Container(
      margin: EdgeInsets.all(minimal ? 2 : 4),
      padding: EdgeInsets.all(minimal ? 2 : 8),
      decoration: BoxDecoration(
        color: layer.isVisible ? null : Colors.grey.shade600,
        border: Border.all(
          color: layer.isSelected ? Colors.blue : Colors.grey.shade700,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: minimal
          ? _buildForSmallSurface(context, appModel, layer, showDelete)
          : _buildForLargeSurface(context, appModel, layer, showDelete),
    );
  }

  Widget _buildForSmallSurface(
    BuildContext context,
    AppModel appModel,
    Layer layer,
    bool showDelete,
  ) {
    return Tooltip(
      margin: const EdgeInsets.only(left: 50),
      message: information(),
      child: Column(
        children: [
          TruncatedTextWidget(text: layer.name, maxLength: 10),
          Stack(
            alignment: Alignment.topCenter,
            children: [
              _buildThumbnailPreview(appModel, layer),
              if (!layer.isVisible)
                const Icon(Icons.visibility_off, color: Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  String information() {
    List<String> texts = [
      '[${layer.id}]',
      layer.name,
      if (!layer.isVisible) 'Hidden',
      'Opacity: ${layer.opacity.toStringAsFixed(0)}',
      'Blend: ${blendModeToText(layer.blendMode)}',
    ];
    return texts.join('\n');
  }

  Widget _buildForLargeSurface(
    BuildContext context,
    AppModel appModel,
    Layer layer,
    bool showDelete,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildLayerName(appModel),
              if (isSelected)
                _buildLayerControls(context, appModel, layer, showDelete),
            ],
          ),
        ),
        _buildThumbnailPreview(appModel, layer),
      ],
    );
  }

  Widget _buildLayerName(final AppModel appModel) {
    return GestureDetector(
      onLongPress: () async {
        final TextEditingController controller =
            TextEditingController(text: layer.name);

        final newName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Layer Name'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Layer Name',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, controller.text);
                  appModel.update();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
        if (newName != null && newName.isNotEmpty) {
          layer.name = newName;
        }
      },
      child: Text(layer.name),
    );
  }

  Widget _buildLayerControls(
    BuildContext context,
    AppModel appModel,
    Layer layer,
    bool showDelete,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        IconButton(
          tooltip: 'Add a layer above',
          icon: const Icon(Icons.playlist_add),
          onPressed: () => _onAddLayer(appModel),
        ),
        IconButton(
          tooltip: 'Blend Mode\n"${blendModeToText(layer.blendMode)}"',
          icon: const Icon(Icons.blender_outlined),
          onPressed: () async {
            layer.blendMode = await showBlendModeMenu(
              context: context,
              selectedBlendMode: layer.blendMode,
            );
          },
        ),
        IconButton(
          tooltip: 'Merge to below layer',
          icon: const Icon(Icons.layers_outlined),
          onPressed: layer == appModel.layers.list.last
              ? null
              : () => _onFlattenLayers(
                    appModel,
                    appModel.selectedLayerIndex,
                    appModel.selectedLayerIndex + 1,
                  ),
        ),
        IconButton(
          tooltip: 'Delete this layer',
          icon: const Icon(Icons.delete_outline),
          onPressed: showDelete ? () => appModel.removeLayer(layer) : null,
        ),
        const SizedBox(
          width: 20,
        ),
        IconButton(
          tooltip: 'Hide/Show this layer',
          icon: Icon(
            layer.isVisible ? Icons.visibility : Icons.visibility_off,
            color: layer.isVisible
                ? Colors.blue
                : const ui.Color.fromARGB(255, 135, 9, 9),
          ),
          onPressed: () => appModel.toggleLayerVisibility(layer),
        ),
      ],
    );
  }

  // Method to insert a new layer above the currently selected one
  void _onAddLayer(final AppModel appModel) {
    final int currentIndex = appModel.selectedLayerIndex;
    final Layer newLayer = appModel.insertLayer(currentIndex);
    appModel.selectedLayerIndex = appModel.layers.getLayerIndex(newLayer);
  }

  // Method to flatten all layers
  void _onFlattenLayers(
    final AppModel appModel,
    final int layerIndexToMerge,
    final int layerIndexToMergIn,
  ) {
    final Layer layerToMege = appModel.layers.get(layerIndexToMerge);
    final Layer receivingLayer = appModel.layers.get(layerIndexToMergIn);

    receivingLayer.mergeFrom(layerToMege);
    appModel.removeLayer(layerToMege);
    if (layerIndexToMergIn > layerIndexToMerge) {
      appModel.selectedLayerIndex = layerIndexToMergIn - 1;
    } else {
      appModel.selectedLayerIndex = layerIndexToMergIn;
    }
  }

  Widget _buildThumbnailPreview(final AppModel appModel, final Layer layer) {
    return SizedBox(
      height: 60,
      width: 60,
      child: ContainerSlider(
        key: ValueKey(layer.name + layer.id),
        minValue: 0.0,
        maxValue: 1.0,
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
