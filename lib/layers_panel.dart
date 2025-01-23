import 'package:flutter/material.dart';
import 'package:fpaint/paint_model.dart';
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
                    return layerRow(context, isSelected, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget layerRow(
    final BuildContext context,
    final bool isSelected,
    final int index,
  ) {
    bool isVisible =
        Provider.of<PaintModel>(context, listen: false).isVisible(index);

    return Container(
      margin: EdgeInsets.all(4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.blue.shade100 : Colors.grey,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Layer ${index + 1}'),
          ),
          IconButton(
            icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
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
