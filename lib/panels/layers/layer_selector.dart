import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/panels/layers/blend_mode.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
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
  final LayerProvider layer;
  final bool minimal;
  final bool isSelected;
  final bool allowRemoveLayer;

  @override
  Widget build(BuildContext context) {
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
          ? _buildForSmallSurface(
              context,
              layer,
              allowRemoveLayer,
            )
          : _buildForLargeSurface(
              context,
              layer,
              allowRemoveLayer,
            ),
    );
  }

  Widget _buildForSmallSurface(
    BuildContext context,
    LayerProvider layer,
    bool allowRemoveLayer,
  ) {
    final shellModel = ShellProvider.of(context);
    final appModel = AppProvider.of(context);

    return Tooltip(
      margin: const EdgeInsets.only(left: 50),
      message: information(),
      child: Column(
        children: [
          TruncatedTextWidget(text: layer.name, maxLength: 10),
          _buildThumbnailPreviewAndVisibility(shellModel, appModel, layer),
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
    LayerProvider layer,
    bool allowRemoveLayer,
  ) {
    final shellModel = ShellProvider.of(context);
    final appModel = AppProvider.of(context);

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
        _buildThumbnailPreviewAndVisibility(shellModel, appModel, layer),
      ],
    );
  }

  List<PopupMenuItem<String>> _buildPopupMenuItems() {
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
        enabled: allowRemoveLayer,
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
    AppProvider appModel,
  ) async {
    switch (value) {
      case 'rename':
        await renameLayer();
        break;
      case 'add':
        _onAddLayer(appModel);
        break;
      case 'delete':
        if (allowRemoveLayer) {
          appModel.layers.remove(layer);
        }
        break;
      case 'merge':
        if (layer != appModel.layers.list.last) {
          _onFlattenLayers(
            appModel,
            appModel.layers.selectedLayerIndex,
            appModel.layers.selectedLayerIndex + 1,
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
        appModel.layers.layersToggleVisibility(layer);
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

  Widget _buildLayerName(final AppProvider appModel) {
    return Row(
      children: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => _buildPopupMenuItems(),
          onSelected: (value) =>
              _handlePopupMenuSelection(value, AppProvider.of(context)),
        ),
        Expanded(
          child: GestureDetector(
            onLongPress: () async {
              await renameLayer();
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
        IconButton(
          tooltip: 'Hide/Show this layer',
          icon: Icon(
            layer.isVisible ? Icons.visibility : Icons.visibility_off,
            color: layer.isVisible
                ? Colors.blue
                : const ui.Color.fromARGB(255, 135, 9, 9),
          ),
          onPressed: () => appModel.layers.layersToggleVisibility(layer),
        ),
      ],
    );
  }

  Future<void> renameLayer() async {
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
              LayersProvider.of(context).update();
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
    AppProvider appModel,
    LayerProvider layer,
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
              allowRemoveLayer ? () => appModel.layers.remove(layer) : null,
        ),
        IconButton(
          tooltip: 'Merge to below layer',
          icon: const Icon(Icons.layers_outlined),
          onPressed: layer == appModel.layers.list.last
              ? null
              : () => _onFlattenLayers(
                    appModel,
                    appModel.layers.selectedLayerIndex,
                    appModel.layers.selectedLayerIndex + 1,
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
      ],
    );
  }

  // Method to insert a new layer above the currently selected one
  void _onAddLayer(final AppProvider appModel) {
    final int currentIndex = appModel.layers.selectedLayerIndex;
    final LayerProvider newLayer = appModel.layerInsertAt(currentIndex);
    appModel.layers.selectedLayerIndex =
        appModel.layers.getLayerIndex(newLayer);
  }

  // Method to flatten all layers
  void _onFlattenLayers(
    final AppProvider appModel,
    final int layerIndexToMerge,
    final int layerIndexToMergIn,
  ) {
    final LayerProvider layerToMege = appModel.layers.get(layerIndexToMerge);
    final LayerProvider receivingLayer =
        appModel.layers.get(layerIndexToMergIn);

    receivingLayer.mergeFrom(layerToMege);
    appModel.layers.remove(layerToMege);
    if (layerIndexToMergIn > layerIndexToMerge) {
      appModel.layers.selectedLayerIndex = layerIndexToMergIn - 1;
    } else {
      appModel.layers.selectedLayerIndex = layerIndexToMergIn;
    }
  }

  Widget _buildThumbnailPreviewAndVisibility(
    final ShellProvider shellModel,
    final AppProvider appModel,
    final LayerProvider layer,
  ) {
    return GestureDetector(
      onLongPress: () {
        showMenu(
          context: context,
          position: const RelativeRect.fromLTRB(0, 0, 0, 0),
          items: _buildPopupMenuItems(),
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
          if (!shellModel.isSidePanelExpanded && !layer.isVisible)
            const Icon(Icons.visibility_off, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildThumbnailPreview(
    final AppProvider appModel,
    final LayerProvider layer,
  ) {
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
