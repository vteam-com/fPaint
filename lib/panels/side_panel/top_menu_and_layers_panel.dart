import 'package:flutter/material.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/panels/side_panel/side_panel_top_menu.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:provider/provider.dart';

/// A widget that displays the top menu and layers panel.
class TopMenuAndLayersPanel extends StatelessWidget {
  const TopMenuAndLayersPanel({super.key});

  @override
  Widget build(final BuildContext context) {
    final ShellProvider shellProvider = ShellProvider.of(context, listen: true);

    return Column(
      children: <Widget>[
        // toolbar
        SidePanelTopMenu(shellProvider: shellProvider),

        Consumer<LayersProvider>(
          builder:
              (
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
}
