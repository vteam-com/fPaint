import 'package:flutter/material.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/panels/share_panel.dart';
import 'package:provider/provider.dart';

class LayersPanel extends StatelessWidget {
  const LayersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.get(context, listen: true);
    return Column(
      children: [
        // toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.file_open_outlined),
              onPressed: () => onFileOpen(context),
            ),
            if (appModel.isSidePanelExpanded)
              IconButton(
                icon: const Icon(Icons.library_add_rounded),
                onPressed: () => _onAddLayer(appModel),
              ),
            if (appModel.isSidePanelExpanded)
              IconButton(
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: () => sharePanel(context),
              ),
            IconButton(
              icon: Icon(
                appModel.isSidePanelExpanded
                    ? Icons.keyboard_double_arrow_left
                    : Icons.keyboard_double_arrow_right,
              ),
              onPressed: () {
                appModel.isSidePanelExpanded = !appModel.isSidePanelExpanded;
              },
            ),
          ],
        ),

        Expanded(
          child: Consumer<AppModel>(
            builder: (context, appModel, child) {
              return ReorderableListView.builder(
                itemCount: appModel.layers.length,
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final Layer layer = appModel.layers.get(oldIndex);
                  appModel.layers.removeByIndex(oldIndex);
                  appModel.layers.insert(newIndex, layer);
                  appModel.selectedLayerIndex = newIndex;
                },
                itemBuilder: (context, index) {
                  final Layer layer = appModel.layers.get(index);
                  return ReorderableDragStartListener(
                    key: Key('$index'),
                    index: index,
                    child: GestureDetector(
                      onTap: () => appModel.selectedLayerIndex = index,
                      onDoubleTap: () => appModel.toggleLayerVisibility(layer),
                      child: LayerSelector(
                        key: Key(layer.id),
                        context: context,
                        layer: layer,
                        minimal: !appModel.isSidePanelExpanded,
                        showDelete: appModel.layers.length >
                            1, // Never allow deletion of the last layer
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Method to add a new layer
  void _onAddLayer(final AppModel appModel) {
    final Layer newLayer = appModel.addLayerTop();
    appModel.selectedLayerIndex = appModel.layers.getLayerIndex(newLayer);
  }
}
