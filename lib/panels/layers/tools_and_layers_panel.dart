import 'package:flutter/material.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/about.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/panels/share_panel.dart';
import 'package:provider/provider.dart';

class ToolsAndLayersPanel extends StatelessWidget {
  const ToolsAndLayersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.get(context, listen: true);
    return Column(
      children: [
        // toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PopupMenuButton<int>(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onSelected: (int result) {
                switch (result) {
                  case 0:
                    onFileNew(context);
                    break;
                  case 1:
                    onFileOpen(context);
                    break;
                  case 2:
                    sharePanel(context);
                    break;
                  case 3:
                    showAboutBox(context);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                const PopupMenuItem<int>(
                  value: 0,
                  child: Text('Start over...'),
                ),
                const PopupMenuItem<int>(
                  value: 1,
                  child: Text('Open file...'),
                ),
                const PopupMenuItem<int>(
                  value: 2,
                  child: Text('Export...'),
                ),
                const PopupMenuItem<int>(
                  value: 3,
                  child: Text('About...'),
                ),
              ],
            ),
            if (appModel.isSidePanelExpanded)
              IconButton(
                tooltip: 'Start over...',
                icon: const Icon(Icons.power_settings_new_outlined),
                onPressed: () => onFileNew(context),
              ),
            if (appModel.isSidePanelExpanded)
              IconButton(
                tooltip: 'Open file...',
                icon: const Icon(Icons.folder_open_outlined),
                onPressed: () => onFileOpen(context),
              ),
            if (appModel.isSidePanelExpanded)
              IconButton(
                tooltip: 'Export...',
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: () => sharePanel(context),
              ),
            IconButton(
              tooltip: 'Expand/Collapse',
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
}
