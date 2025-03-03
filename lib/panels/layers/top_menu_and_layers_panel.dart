import 'package:flutter/material.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/models/localized_strings.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/panels/layers/menu.dart';
import 'package:fpaint/panels/share_panel.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:provider/provider.dart';

class TopMenuAndLayersPanel extends StatelessWidget {
  const TopMenuAndLayersPanel({super.key});

  @override
  Widget build(final BuildContext context) {
    final ShellProvider shellProvider = ShellProvider.of(context, listen: true);

    return Column(
      children: <Widget>[
        // toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const MainMenu(),
            if (shellProvider.isSidePanelExpanded)
              buildIconButton(
                tooltip: strings[StringId.startOverTooltip]!,
                icon: Icons.power_settings_new_outlined,
                onPressed: () => onFileNew(context),
              ),
            if (shellProvider.isSidePanelExpanded)
              buildIconButton(
                tooltip: strings[StringId.importTooltip]!,
                icon: Icons.file_download_outlined,
                onPressed: () => onFileOpen(context),
              ),
            if (shellProvider.isSidePanelExpanded)
              buildIconButton(
                tooltip: strings[StringId.exportTooltip]!,
                icon: Icons.ios_share_outlined,
                onPressed: () => sharePanel(context),
              ),
            if (!shellProvider.showMenu)
              buildIconButton(
                tooltip: strings[StringId.exportTooltip]!,
                icon: shellProvider.isSidePanelExpanded
                    ? Icons.keyboard_double_arrow_left
                    : Icons.keyboard_double_arrow_right,
                onPressed: () {
                  shellProvider.isSidePanelExpanded =
                      !shellProvider.isSidePanelExpanded;
                },
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
                        minimal: !shellProvider.isSidePanelExpanded,
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
}
