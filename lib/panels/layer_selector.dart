import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/truncated_text.dart';

class LayerSelector extends StatelessWidget {
  const LayerSelector({
    super.key,
    required this.context,
    required this.layer,
    required this.minimal,
    required this.index,
    required this.showDelete,
    required this.onRemoveLayer,
  });

  final BuildContext context;
  final Layer layer;
  final int index;
  final bool showDelete;
  final bool minimal;
  final Function(int) onRemoveLayer;

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.get(context);
    return Container(
      key: ValueKey(index),
      margin: EdgeInsets.all(minimal ? 2 : 4),
      padding: EdgeInsets.all(minimal ? 2 : 8),
      decoration: BoxDecoration(
        color: minimal ? (layer.isVisible ? null : Colors.grey) : null,
        border: Border.all(
          color: layer.isSelected ? Colors.blue : Colors.grey.shade300,
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
                  onPressed: () => appModel.toggleLayerVisibility(index),
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
