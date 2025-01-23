import 'package:flutter/material.dart';
import 'package:fpaint/models/paint_model.dart';
import 'package:provider/provider.dart';

class LayersPanel extends StatelessWidget {
  final int selectedLayerIndex;
  final Function(int) onSelectLayer;
  final Function() onAddLayer;
  final Function(int) onRemoveLayer;
  final Function(int) onToggleViewLayer;

  const LayersPanel({
    super.key,
    required this.selectedLayerIndex,
    required this.onSelectLayer,
    required this.onAddLayer,
    required this.onRemoveLayer,
    required this.onToggleViewLayer,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.grey.shade200,
      child: SizedBox(
        width: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // toolbar
            Row(children: [
              IconButton(
                icon: Icon(Icons.add),
                onPressed: onAddLayer,
              ),
            ]),
            Expanded(
              child: Consumer<PaintModel>(
                builder: (context, paintModel, child) {
                  return ReorderableListView.builder(
                    itemCount: paintModel.layers.length,
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final PaintLayer layer = paintModel.layers[oldIndex];
                      paintModel.layers.removeAt(oldIndex);
                      paintModel.layers.insert(newIndex, layer);
                      if (selectedLayerIndex == oldIndex) {
                        onSelectLayer(newIndex);
                      }
                    },
                    itemBuilder: (context, index) {
                      final PaintLayer layer = paintModel.layers[index];
                      final bool isSelected = index == selectedLayerIndex;
                      return ReorderableDragStartListener(
                        key: Key('$index'),
                        index: index,
                        child: GestureDetector(
                          onTap: () => onSelectLayer(index),
                          child: layerRow(context, isSelected, index, layer),
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
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () => onRemoveLayer(index),
          ),
        ],
      ),
    );
  }
}
