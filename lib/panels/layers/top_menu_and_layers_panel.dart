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
    final appModel = AppModel.of(context, listen: true);

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
                    saveFile(appModel).then(
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
                buildMenuItem(
                  value: MenuIds.newFile,
                  text: 'Start over...',
                  icon: Icons.power_settings_new_outlined,
                ),
                buildMenuItem(
                  value: MenuIds.openFile,
                  text: 'Import...',
                  icon: Icons.file_download_outlined,
                ),
                buildMenuItem(
                  value: MenuIds.export,
                  text: 'Export...',
                  icon: Icons.ios_share_outlined,
                ),
                if (!kIsWeb && appModel.loadedFileName.isNotEmpty)
                  buildMenuItem(
                    value: MenuIds.save,
                    text: 'Save "${appModel.loadedFileName}"',
                    icon: Icons.check_circle_outline,
                  ),
                buildMenuItem(
                  value: MenuIds.canvasSize,
                  text: 'Canvas...',
                  icon: Icons.edit,
                ),
                buildMenuItem(
                  value: MenuIds.about,
                  text: 'About...',
                  icon: Icons.info_outline,
                ),
              ],
            ),
            if (appModel.isSidePanelExpanded)
              buildIconButton(
                tooltip: 'Start over...',
                icon: Icons.power_settings_new_outlined,
                onPressed: () => onFileNew(context),
              ),
            if (appModel.isSidePanelExpanded)
              buildIconButton(
                tooltip: 'Import...',
                icon: Icons.file_download_outlined,
                onPressed: () => onFileOpen(context),
              ),
            if (appModel.isSidePanelExpanded)
              buildIconButton(
                tooltip: 'Export...',
                icon: Icons.ios_share_outlined,
                onPressed: () => sharePanel(context),
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
                        allowRemoveLayer: appModel.layers.length > 1,
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

  PopupMenuEntry<int> buildMenuItem({
    required int value,
    required String text,
    IconData? icon,
    VoidCallback? onPressed,
  }) {
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 18),
          if (icon != null) const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget buildIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}
