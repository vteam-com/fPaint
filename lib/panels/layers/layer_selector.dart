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
    required this.allowRemoveLayer,
  });

  final BuildContext context;
  final Layer layer;
  final bool minimal;
  final bool isSelected;
  final bool allowRemoveLayer;

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.of(context);
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
          ? _buildForSmallSurface(context, appModel, layer, allowRemoveLayer)
          : _buildForLargeSurface(context, appModel, layer, allowRemoveLayer),
    );
  }

  Widget _buildForSmallSurface(
    BuildContext context,
    AppModel appModel,
    Layer layer,
    bool allowRemoveLayer,
  ) {
    return Tooltip(
      margin: const EdgeInsets.only(left: 50),
      message: information(),
      child: Column(
        children: [
          TruncatedTextWidget(text: layer.name, maxLength: 10),
          _buildThumbnailPreviewAndVisibility(appModel, layer),
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
    bool allowRemoveLayer,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildLayerName(appModel),
              if (isSelected)
                _buildLayerControls(context, appModel, layer, allowRemoveLayer),
            ],
          ),
        ),
        _buildThumbnailPreviewAndVisibility(appModel, layer),
      ],
    );
  }

  List<PopupMenuItem<String>> _buildPopupMenuItems(AppModel appModel) {
    return [
      const PopupMenuItem(
        value: 'rename',
        enabled: true,
        child: Row(
          children: [
            Icon(Icons.edit),
            SizedBox(width: 8),
            Text('Rename layer'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'add',
        enabled: true,
        child: Row(
          children: [
            Icon(Icons.playlist_add),
            SizedBox(width: 8),
            Text('Add a layer above'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        enabled: allowRemoveLayer,
        child: const Row(
          children: [
            Icon(Icons.playlist_remove),
            SizedBox(width: 8),
            Text('Delete this layer'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'merge',
        enabled: layer != appModel.layers.list.last,
        child: const Row(
          children: [
            Icon(Icons.layers_outlined),
            SizedBox(width: 8),
            Text('Merge to below layer'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'blend',
        enabled: true,
        child: Row(
          children: [
            Icon(Icons.blender_outlined),
            SizedBox(width: 8),
            Text('Change Blend Mode'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'visibility',
        enabled: true,
        child: Row(
          children: [
            Icon(
              layer.isVisible ? Icons.visibility : Icons.visibility_off,
              color: layer.isVisible
                  ? Colors.blue
                  : const ui.Color.fromARGB(255, 135, 9, 9),
            ),
            const SizedBox(width: 8),
            Text(layer.isVisible ? 'Hide layer' : 'Show layer'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'allHide',
        enabled: true,
        child: Row(
          children: [
            Icon(
              Icons.visibility_off,
            ),
            SizedBox(width: 8),
            Text('Hide all other layers'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'allShow',
        enabled: true,
        child: Row(
          children: [
            Icon(
              Icons.visibility,
            ),
            SizedBox(width: 8),
            Text('Show all layers'),
          ],
        ),
      ),
    ];
  }

  Future<void> _handlePopupMenuSelection(
    String value,
    AppModel appModel,
  ) async {
    switch (value) {
      case 'rename':
        await renameLayer(appModel);
        break;
      case 'add':
        _onAddLayer(appModel);
        break;
      case 'delete':
        if (allowRemoveLayer) {
          appModel.removeLayer(layer);
        }
        break;
      case 'merge':
        if (layer != appModel.layers.list.last) {
          _onFlattenLayers(
            appModel,
            appModel.selectedLayerIndex,
            appModel.selectedLayerIndex + 1,
          );
        }
        break;
      case 'blend':
        layer.blendMode = await showBlendModeMenu(
          context: context,
          selectedBlendMode: layer.blendMode,
        );
        break;
      case 'visibility':
        appModel.toggleLayerVisibility(layer);
        break;
      case 'allHide':
        appModel.layers.hideShowAllExcept(layer, false);
        appModel.update();
        break;
      case 'allShow':
        appModel.layers.hideShowAllExcept(layer, true);
        appModel.update();
        break;
    }
  }

  Widget _buildLayerName(final AppModel appModel) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPress: () async {
              await renameLayer(appModel);
            },
            child: Text(
              layer.name,
              style: TextStyle(
                fontSize: 13 * 1.3,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.blue.shade100 : Colors.grey.shade400,
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => _buildPopupMenuItems(AppModel.of(context)),
          onSelected: (value) =>
              _handlePopupMenuSelection(value, AppModel.of(context)),
        ),
      ],
    );
  }

  Future<void> renameLayer(AppModel appModel) async {
    final TextEditingController controller =
        TextEditingController(text: layer.name);

    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
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
  }

  Widget _buildLayerControls(
    BuildContext context,
    AppModel appModel,
    Layer layer,
    bool allowRemoveLayer,
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
          tooltip: 'Delete this layer',
          icon: const Icon(Icons.playlist_remove),
          onPressed:
              allowRemoveLayer ? () => appModel.removeLayer(layer) : null,
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
          tooltip: 'Blend Mode\n"${blendModeToText(layer.blendMode)}"',
          icon: const Icon(Icons.blender_outlined),
          onPressed: () async {
            layer.blendMode = await showBlendModeMenu(
              context: context,
              selectedBlendMode: layer.blendMode,
            );
          },
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

  Widget _buildThumbnailPreviewAndVisibility(
    final AppModel appModel,
    final Layer layer,
  ) {
    return GestureDetector(
      onLongPress: () {
        showMenu(
          context: context,
          position: const RelativeRect.fromLTRB(0, 0, 0, 0),
          items: _buildPopupMenuItems(appModel),
          elevation: 8,
        ).then((value) {
          if (value != null) {
            _handlePopupMenuSelection(value, appModel);
          }
        });
      },
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          _buildThumbnailPreview(appModel, layer),
          if (!layer.isVisible)
            const Icon(Icons.visibility_off, color: Colors.red),
        ],
      ),
    );
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
