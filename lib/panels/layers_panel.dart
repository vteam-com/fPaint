import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/layer_selector.dart';
import 'package:fpaint/panels/share_panel.dart';
import 'package:provider/provider.dart';

class LayersPanel extends StatelessWidget {
  const LayersPanel({
    super.key,
    required this.selectedLayerIndex,
    required this.onSelectLayer,
    required this.onAddLayer,
    required this.onFileOpen,
    required this.onRemoveLayer,
  });
  final int selectedLayerIndex;
  final Function(int) onSelectLayer;
  final Function() onAddLayer;
  final Function() onFileOpen;
  final Function(int) onRemoveLayer;

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
              onPressed: onFileOpen,
            ),
            if (appModel.isSidePanelExpanded)
              IconButton(
                icon: const Icon(Icons.library_add_rounded),
                onPressed: onAddLayer,
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
                  appModel.layers.remove(oldIndex);
                  appModel.layers.insert(newIndex, layer);
                  if (selectedLayerIndex == oldIndex) {
                    onSelectLayer(newIndex);
                  }
                },
                itemBuilder: (context, index) {
                  final Layer layer = appModel.layers.get(index);
                  return ReorderableDragStartListener(
                    key: Key('$index'),
                    index: index,
                    child: GestureDetector(
                      onTap: () => onSelectLayer(index),
                      onDoubleTap: () => appModel.toggleLayerVisibility(index),
                      child: LayerSelector(
                        context: context,
                        minimal: !appModel.isSidePanelExpanded,
                        layer: layer,
                        index: index,
                        showDelete: appModel.layers.length > 1,
                        onRemoveLayer: onRemoveLayer,
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
}
