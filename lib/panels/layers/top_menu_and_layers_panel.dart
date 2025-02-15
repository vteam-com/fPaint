import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/models/localized_strings.dart';
import 'package:fpaint/models/menu_model.dart';
import 'package:fpaint/panels/about.dart';
import 'package:fpaint/panels/canvas_settings.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/panels/share_panel.dart';

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
            mainMenu(context, appModel),
            if (appModel.isSidePanelExpanded)
              buildIconButton(
                tooltip: strings[StringId.startOverTooltip]!,
                icon: Icons.power_settings_new_outlined,
                onPressed: () => onFileNew(context),
              ),
            if (appModel.isSidePanelExpanded)
              buildIconButton(
                tooltip: strings[StringId.importTooltip]!,
                icon: Icons.file_download_outlined,
                onPressed: () => onFileOpen(context),
              ),
            if (appModel.isSidePanelExpanded)
              buildIconButton(
                tooltip: strings[StringId.exportTooltip]!,
                icon: Icons.ios_share_outlined,
                onPressed: () => sharePanel(context),
              ),
            buildIconButton(
              tooltip: strings[StringId.exportTooltip]!,
              icon: appModel.isSidePanelExpanded
                  ? Icons.keyboard_double_arrow_left
                  : Icons.keyboard_double_arrow_right,
              onPressed: () =>
                  appModel.isSidePanelExpanded = !appModel.isSidePanelExpanded,
            ),
          ],
        ),

        Expanded(
          child: ReorderableListView.builder(
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
                  onDoubleTap: () => appModel.layersToggleVisibility(layer),
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

  Widget mainMenu(final BuildContext context, final AppModel appModel) {
    return PopupMenuButton<int>(
      tooltip: strings[StringId.menuTooltip],
      icon: const Icon(Icons.menu),
      onSelected: (int result) =>
          onDropDownMenuSelection(context, appModel, result),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        buildMenuItem(
          value: MenuIds.newFile,
          text: strings[StringId.startOver]!,
          icon: Icons.power_settings_new_outlined,
        ),
        buildMenuItem(
          value: MenuIds.openFile,
          text: strings[StringId.import]!,
          icon: Icons.file_download_outlined,
        ),
        buildMenuItem(
          value: MenuIds.export,
          text: strings[StringId.export]!,
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
          text: strings[StringId.canvas]!,
          icon: Icons.edit,
        ),
        buildMenuItem(
          value: MenuIds.about,
          text: strings[StringId.about]!,
          icon: Icons.info_outline,
        ),
      ],
    );
  }

  void onDropDownMenuSelection(
    final BuildContext context,
    final AppModel appModel,
    int result,
  ) {
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
                content: Text(
                  '${strings[StringId.savedMessage]}${appModel.loadedFileName}',
                ),
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
  }
}
