import 'package:flutter/material.dart';
import 'package:fpaint/paint_model.dart';

class ToolsPanel extends StatelessWidget {
  final ShapeType currentShapeType;
  final Color currentColor;
  final Function(ShapeType) onShapeSelected;
  final VoidCallback onColorPicker;

  const ToolsPanel({
    super.key,
    required this.currentShapeType,
    required this.currentColor,
    required this.onShapeSelected,
    required this.onColorPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.grey.shade200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Pencil
          IconButton(
            icon: Icon(Icons.edit_outlined),
            onPressed: () => onShapeSelected(ShapeType.pencil),
            color: currentShapeType == ShapeType.pencil ? currentColor : null,
          ),

          // Line
          IconButton(
            icon: Icon(Icons.line_axis),
            onPressed: () => onShapeSelected(ShapeType.line),
            color: currentShapeType == ShapeType.pencil ? currentColor : null,
          ),

          // Rectangle
          IconButton(
            icon: Icon(Icons.crop_square),
            onPressed: () => onShapeSelected(ShapeType.rectangle),
            color:
                currentShapeType == ShapeType.rectangle ? currentColor : null,
          ),
          // Circle
          IconButton(
            icon: Icon(Icons.circle_outlined),
            onPressed: () => onShapeSelected(ShapeType.circle),
            color: currentShapeType == ShapeType.circle ? currentColor : null,
          ),
          IconButton(
            icon: Icon(Icons.color_lens),
            onPressed: onColorPicker,
            color: currentColor,
          ),
        ],
      ),
    );
  }
}
