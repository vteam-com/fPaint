import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/models/localized_strings.dart';
import 'package:fpaint/models/menu_model.dart';
import 'package:fpaint/panels/about.dart';
import 'package:fpaint/panels/canvas_settings.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/panels/share_panel.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:provider/provider.dart';

class TopMenuAndLayersPanel extends StatelessWidget {
  const TopMenuAndLayersPanel({super.key});

  @override
  Widget build(final BuildContext context) {
    final ShellProvider shellModel = ShellProvider.of(context, listen: true);

    return Column(
      children: <Widget>[
        // toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            mainMenu(context),
            if (shellModel.isSidePanelExpanded)
              buildIconButton(
                tooltip: strings[StringId.startOverTooltip]!,
                icon: Icons.power_settings_new_outlined,
                onPressed: () => onFileNew(context),
              ),
            if (shellModel.isSidePanelExpanded)
              buildIconButton(
                tooltip: strings[StringId.importTooltip]!,
                icon: Icons.file_download_outlined,
                onPressed: () => onFileOpen(context),
              ),
            if (shellModel.isSidePanelExpanded)
              buildIconButton(
                tooltip: strings[StringId.exportTooltip]!,
                icon: Icons.ios_share_outlined,
                onPressed: () => sharePanel(context),
              ),
            buildIconButton(
              tooltip: strings[StringId.exportTooltip]!,
              icon: shellModel.isSidePanelExpanded
                  ? Icons.keyboard_double_arrow_left
                  : Icons.keyboard_double_arrow_right,
              onPressed: () => shellModel.isSidePanelExpanded =
                  !shellModel.isSidePanelExpanded,
            ),
          ],
        ),

        Consumer<LayersProvider>(
          builder: (
            final BuildContext context2,
            final LayersProvider layers,
            final Widget? child,
          ) {
            return Expanded(
              child: ReorderableListView.builder(
                itemCount: layers.length,
                buildDefaultDragHandles: false,
                onReorder: (final int oldIndex, int newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final LayerProvider layer = layers.get(oldIndex);
                  layers.removeByIndex(oldIndex);
                  layers.insert(newIndex, layer);
                  layers.selectedLayerIndex = newIndex;
                },
                itemBuilder: (final BuildContext context, final int index) {
                  final LayerProvider layer = layers.get(index);
                  return ReorderableDragStartListener(
                    key: Key('$index'),
                    index: index,
                    child: GestureDetector(
                      onTap: () => layers.selectedLayerIndex = index,
                      onDoubleTap: () => layers.layersToggleVisibility(layer),
                      child: LayerSelector(
                        context: context2,
                        layer: layer,
                        minimal: !shellModel.isSidePanelExpanded,
                        isSelected: layers.selectedLayerIndex == index,
                        allowRemoveLayer: index != layers.length - 1,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  PopupMenuEntry<int> buildMenuItem({
    required final int value,
    required final String text,
    final IconData? icon,
    final VoidCallback? onPressed,
  }) {
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: <Widget>[
          if (icon != null) Icon(icon, size: 18),
          if (icon != null) const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget buildIconButton({
    required final String tooltip,
    required final IconData icon,
    required final VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }

  Widget mainMenu(
    final BuildContext context,
  ) {
    final ShellProvider shellModel = ShellProvider.of(context);

    return PopupMenuButton<int>(
      tooltip: strings[StringId.menuTooltip],
      icon: const Icon(Icons.menu),
      onSelected: (final int result) =>
          onDropDownMenuSelection(context, result),
      itemBuilder: (final BuildContext context) => <PopupMenuEntry<int>>[
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
        if (!kIsWeb && shellModel.loadedFileName.isNotEmpty)
          buildMenuItem(
            value: MenuIds.save,
            text: 'Save "${shellModel.loadedFileName}"',
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
    final int result,
  ) {
    final ShellProvider shellModel = ShellProvider.of(context);
    final LayersProvider layers = LayersProvider.of(context);

    switch (result) {
      case MenuIds.newFile:
        onFileNew(context);
        break;
      case MenuIds.openFile:
        onFileOpen(context);
        break;
      case MenuIds.save:
        saveFile(
          shellModel,
          layers,
        ).then(
            // ignore: use_build_context_synchronously
            (final _) {
          layers.clearHasChanged();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${strings[StringId.savedMessage]}${shellModel.loadedFileName}',
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
