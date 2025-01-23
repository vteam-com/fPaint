import 'package:flutter/material.dart';
import 'package:fpaint/paint_model.dart';
import 'package:provider/provider.dart';

class LayersPanel extends StatelessWidget {
  final int selectedLayerIndex;
  final Function(int) onSelectLayer;
  final Function() onAddLayer;
  final Function(int) onRemoveLayer;

  const LayersPanel({
    super.key,
    required this.selectedLayerIndex,
    required this.onSelectLayer,
    required this.onAddLayer,
    required this.onRemoveLayer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: Colors.grey,
      child: Column(
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
                return ListView.builder(
                  itemCount: paintModel.layers.length,
                  itemBuilder: (context, index) {
                    final bool isSelected = index == selectedLayerIndex;
                    return layerRow(isSelected, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget layerRow(bool isSelected, int index) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        selected: isSelected,
        title: Text('Layer ${index + 1}'),
        onTap: () => onSelectLayer(index),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline),
          onPressed: () => onRemoveLayer(index),
        ),
      ),
    );
  }
}
