import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/share_panel.dart';
import 'package:fpaint/widgets/truncated_text.dart';
import 'package:provider/provider.dart';

class LayersPanel extends StatelessWidget {
  const LayersPanel({
    super.key,
    required this.selectedLayerIndex,
    required this.onSelectLayer,
    required this.onAddLayer,
    required this.onFileOpen,
    required this.onRemoveLayer,
    required this.onToggleViewLayer,
  });
  final int selectedLayerIndex;
  final Function(int) onSelectLayer;
  final Function() onAddLayer;
  final Function() onFileOpen;
  final Function(int) onRemoveLayer;
  final Function(int) onToggleViewLayer;

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
                  final bool isSelected = index == selectedLayerIndex;
                  return ReorderableDragStartListener(
                    key: Key('$index'),
                    index: index,
                    child: GestureDetector(
                      onTap: () => onSelectLayer(index),
                      onDoubleTap: () => onToggleViewLayer(index),
                      child: layerSelector(
                        context: context,
                        minimal: !appModel.isSidePanelExpanded,
                        layer: layer,
                        index: index,
                        isSelected: isSelected,
                        showDelete: appModel.layers.length > 1,
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

  Widget layerSelector({
    required final BuildContext context,
    required final bool isSelected,
    required final int index,
    required final Layer layer,
    required final bool showDelete,
    required final bool minimal,
  }) {
    return Container(
      key: ValueKey(index),
      margin: EdgeInsets.all(minimal ? 2 : 4),
      padding: EdgeInsets.all(minimal ? 2 : 8),
      decoration: BoxDecoration(
        color: minimal ? (layer.isVisible ? null : Colors.grey) : null,
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey.shade300,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: minimal
          ? TruncatedTextWidget(text: layer.name)
          : Row(
              children: [
                Expanded(
                  child: Text(layer.name),
                ),
                IconButton(
                  icon: Icon(
                    layer.isVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => onToggleViewLayer(index),
                ),
                if (showDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onRemoveLayer(index),
                  ),
              ],
            ),
    );
  }
}
