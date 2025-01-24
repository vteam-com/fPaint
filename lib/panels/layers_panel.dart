import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:provider/provider.dart';

class LayersPanel extends StatelessWidget {
  const LayersPanel({
    super.key,
    required this.selectedLayerIndex,
    required this.onSelectLayer,
    required this.onAddLayer,
    required this.onShare,
    required this.onRemoveLayer,
    required this.onToggleViewLayer,
  });
  final int selectedLayerIndex;
  final Function(int) onSelectLayer;
  final Function() onAddLayer;
  final Function() onShare;
  final Function(int) onRemoveLayer;
  final Function(int) onToggleViewLayer;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.grey.shade200,
      child: SizedBox(
        width: 200,
        height: 500,
        child: Column(
          children: [
            // toolbar
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: onAddLayer,
                ),
                IconButton(
                  icon: Icon(Icons.ios_share_outlined),
                  onPressed: onShare,
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
                      final PaintLayer layer = appModel.layers.get(oldIndex);
                      appModel.layers.remove(oldIndex);
                      appModel.layers.insert(newIndex, layer);
                      if (selectedLayerIndex == oldIndex) {
                        onSelectLayer(newIndex);
                      }
                    },
                    itemBuilder: (context, index) {
                      final PaintLayer layer = appModel.layers.get(index);
                      final bool isSelected = index == selectedLayerIndex;
                      return ReorderableDragStartListener(
                        key: Key('$index'),
                        index: index,
                        child: GestureDetector(
                          onTap: () => onSelectLayer(index),
                          child: layerRow(
                            context,
                            isSelected,
                            index,
                            layer,
                            appModel.layers.length > 1,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget layerRow(
    final BuildContext context,
    final bool isSelected,
    final int index,
    final PaintLayer layer,
    final bool showDelete,
  ) {
    return Container(
      key: ValueKey(index),
      margin: EdgeInsets.all(4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey.shade300,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(layer.name),
          ),
          IconButton(
            icon:
                Icon(layer.isVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () => onToggleViewLayer(index),
          ),
          if (showDelete)
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () => onRemoveLayer(index),
            ),
        ],
      ),
    );
  }
}
