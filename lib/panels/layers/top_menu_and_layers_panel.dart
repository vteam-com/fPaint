import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/models/menu_model.dart';
import 'package:fpaint/panels/about.dart';
import 'package:fpaint/panels/canvas_settings.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/panels/share_panel.dart';
import 'package:provider/provider.dart';

class TopMenuAndLayersPanel extends StatelessWidget {
  const TopMenuAndLayersPanel({super.key});

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
                  case MenuIds.newFile:
                    onFileNew(context);
                    break;
                  case MenuIds.openFile:
                    onFileOpen(context);
                    break;
                  case MenuIds.save:
                    saveFile(context, appModel).then(
                        // ignore: use_build_context_synchronously
                        (_) {
                      appModel.layers.clearHasChanged();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Saved ${appModel.loadedFileName}'),
                          ),
                        );
                      }
                    });
                    break;
                  case MenuIds.export:
                    sharePanel(context);
                    break;
                  case MenuIds.canvasSize:
                    showCanvasSettings(context);
                    break;
                  case MenuIds.about:
                    showAboutBox(context);
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                const PopupMenuItem<int>(
                  value: MenuIds.newFile,
                  child: Text('Start over...'),
                ),
                const PopupMenuItem<int>(
                  value: MenuIds.openFile,
                  child: Text('Open file...'),
                ),
                const PopupMenuItem<int>(
                  value: MenuIds.export,
                  child: Text('Export...'),
                ),
                if (!kIsWeb)
                  const PopupMenuItem<int>(
                    value: MenuIds.save,
                    child: Text('Save...'),
                  ),
                const PopupMenuItem<int>(
                  value: MenuIds.canvasSize,
                  child: Text('Canvas...'),
                ),
                const PopupMenuItem<int>(
                  value: MenuIds.about,
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
                        isSelected: appModel.selectedLayerIndex == index,
                        allowRemoveLayer: appModel.layers.length >
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
