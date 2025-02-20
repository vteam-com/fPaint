import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/panels/layers/blend_mode.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
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
  Widget build(final BuildContext context) {
    final LayersProvider layers = LayersProvider.of(context);
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
              layers,
              layer,
              allowRemoveLayer,
            ),
    );
  }

  Widget _buildForSmallSurface(
    final BuildContext context,
    final LayerProvider layer,
    final bool allowRemoveLayer,
  ) {
    final LayersProvider layers = LayersProvider.of(context);

    return Tooltip(
      margin: const EdgeInsets.only(left: 50),
      message: information(),
      child: Column(
        children: <Widget>[
          TruncatedTextWidget(text: layer.name, maxLength: 10),
          _buildThumbnailPreviewAndVisibility(
            layers,
            layer,
          ),
        ],
      ),
    );
  }

  String information() {
    final List<String> texts = <String>[
      '[${layer.id}]',
      layer.name,
      if (!layer.isVisible) 'Hidden',
      'Opacity: ${layer.opacity.toStringAsFixed(0)}',
      'Blend: ${blendModeToText(layer.blendMode)}',
    ];
    return texts.join('\n');
  }

  Widget _buildForLargeSurface(
    final BuildContext context,
    final LayersProvider layers,
    final LayerProvider layer,
    final bool allowRemoveLayer,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            children: <Widget>[
              _buildLayerName(layers),
              if (isSelected)
                _buildLayerControls(context, layers, layer, allowRemoveLayer),
            ],
          ),
        ),
        _buildThumbnailPreviewAndVisibility(
          layers,
          layer,
        ),
      ],
    );
  }

  List<PopupMenuItem<String>> _buildPopupMenuItems() {
    return <PopupMenuItem<String>>[
      const PopupMenuItem<String>(
        value: 'rename',
        enabled: true,
        child: Row(
          children: <Widget>[
            Icon(Icons.edit),
            SizedBox(width: 8),
            Text('Rename layer'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'add',
        enabled: true,
        child: Row(
          children: <Widget>[
            Icon(Icons.playlist_add),
            SizedBox(width: 8),
            Text('Add a layer above'),
          ],
        ),
      ),
      if (allowRemoveLayer)
        PopupMenuItem<String>(
          value: 'delete',
          enabled: allowRemoveLayer,
          child: const Row(
            children: <Widget>[
              Icon(Icons.playlist_remove),
              SizedBox(width: 8),
              Text('Delete this layer'),
            ],
          ),
        ),
      if (allowRemoveLayer)
        PopupMenuItem<String>(
          value: 'merge',
          enabled: allowRemoveLayer,
          child: const Row(
            children: <Widget>[
              Icon(Icons.layers_outlined),
              SizedBox(width: 8),
              Text('Merge to below layer'),
            ],
          ),
        ),
      if (allowRemoveLayer)
        const PopupMenuItem<String>(
          value: 'blend',
          enabled: true,
          child: Row(
            children: <Widget>[
              Icon(Icons.blender_outlined),
              SizedBox(width: 8),
              Text('Change Blend Mode'),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: 'visibility',
        enabled: true,
        child: Row(
          children: <Widget>[
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
      const PopupMenuItem<String>(
        value: 'allHide',
        enabled: true,
        child: Row(
          children: <Widget>[
            Icon(
              Icons.visibility_off,
            ),
            SizedBox(width: 8),
            Text('Hide all other layers'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'allShow',
        enabled: true,
        child: Row(
          children: <Widget>[
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
    final String value,
    final LayersProvider layers,
  ) async {
    switch (value) {
      case 'rename':
        await renameLayer();
        break;
      case 'add':
        _onAddLayer(layers);
        break;
      case 'delete':
        if (allowRemoveLayer) {
          layers.remove(layer);
        }
        break;
      case 'merge':
        if (layer != layers.list.last) {
          _onMergeLayer(
            layers,
            layers.selectedLayerIndex,
            layers.selectedLayerIndex + 1,
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
        layers.layersToggleVisibility(layer);
        break;
      case 'allHide':
        layers.hideShowAllExcept(layer, false);
        layers.update();
        break;
      case 'allShow':
        layers.hideShowAllExcept(layer, true);
        layers.update();
        break;
    }
  }

  Widget _buildLayerName(final LayersProvider layers) {
    return Row(
      children: <Widget>[
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (final BuildContext context) => _buildPopupMenuItems(),
          onSelected: (final String value) =>
              _handlePopupMenuSelection(value, layers),
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
          onPressed: () => layers.layersToggleVisibility(layer),
        ),
      ],
    );
  }

  Future<void> renameLayer() async {
    final TextEditingController controller =
        TextEditingController(text: layer.name);

    final String? newName = await showDialog<String>(
      context: context,
      builder: (final BuildContext context) => AlertDialog(
        title: const Text('Layer Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Layer Name',
          ),
        ),
        actions: <Widget>[
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
    final BuildContext context,
    final LayersProvider layers,
    final LayerProvider layer,
    final bool allowRemoveLayer,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: <Widget>[
        IconButton(
          tooltip: 'Add a layer above',
          icon: const Icon(Icons.playlist_add),
          onPressed: () => _onAddLayer(layers),
        ),
        if (allowRemoveLayer)
          IconButton(
            tooltip: 'Delete this layer',
            icon: const Icon(Icons.playlist_remove),
            onPressed: allowRemoveLayer ? () => layers.remove(layer) : null,
          ),
        if (allowRemoveLayer)
          IconButton(
            tooltip: 'Merge to below layer',
            icon: const Icon(Icons.layers_outlined),
            onPressed: layer == layers.list.last
                ? null
                : () => _onMergeLayer(
                      layers,
                      layers.selectedLayerIndex,
                      layers.selectedLayerIndex + 1,
                    ),
          ),
        if (allowRemoveLayer)
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
        if (this.layer.backgroundColor != null)
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: ColorPreview(
              color: this.layer.backgroundColor ?? Colors.transparent,
              onPressed: () {
                showColorPicker(
                  context: context,
                  title: 'Background Color',
                  color: this.layer.backgroundColor ?? Colors.transparent,
                  onSelectedColor: (final Color color) {
                    this.layer.backgroundColor = color;
                    layer.clearCache();
                    layers.update();
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // Method to insert a new layer above the currently selected one
  void _onAddLayer(final LayersProvider layers) {
    final UndoProvider undoProvider = UndoProvider();

    final int currentIndex = layers.selectedLayerIndex;

    undoProvider.executeAction(
      name: 'Add Layer',
      forward: () {
        // Add
        final LayerProvider newLayer = layers.insertAt(currentIndex);
        // Change selected layer to the new added layer
        layers.selectedLayerIndex = layers.getLayerIndex(newLayer);
      },
      backward: () {
        layers.removeByIndex(currentIndex);
        layers.selectedLayerIndex = currentIndex;
      },
    );
  }

  // Method to flatten all layers
  void _onMergeLayer(
    final LayersProvider layers,
    final int indexFrom,
    final int indexTo,
  ) {
    layers.mergeLayers(indexFrom, indexTo);
  }

  Widget _buildThumbnailPreviewAndVisibility(
    final LayersProvider layers,
    final LayerProvider layer,
  ) {
    return GestureDetector(
      onLongPress: () {
        showMenu(
          context: context,
          position: const RelativeRect.fromLTRB(0, 0, 0, 0),
          items: _buildPopupMenuItems(),
          elevation: 8,
        ).then((final String? value) {
          if (value != null) {
            _handlePopupMenuSelection(value, layers);
          }
        });
      },
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          _buildThumbnailPreview(layers, layer),
          if (minimal && !layer.isVisible)
            const Icon(Icons.visibility_off, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildThumbnailPreview(
    final LayersProvider layers,
    final LayerProvider layer,
  ) {
    return SizedBox(
      height: 60,
      width: 60,
      child: ContainerSlider(
        key: ValueKey<String>(layer.name + layer.id),
        minValue: 0.0,
        maxValue: 1.0,
        initialValue: layer.opacity,
        onSlideStart: () {
          // appModel.update();
        },
        onChanged: (final double value) => layer.opacity = value,
        onChangeEnd: (final double value) {
          layer.opacity = value;
          layers.update();
        },
        onSlideEnd: () => layers.update(),
        child: LayerThumbnail(layer: layer),
      ),
    );
  }
}
