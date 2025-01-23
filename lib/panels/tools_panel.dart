import 'package:flutter/material.dart';
import 'package:fpaint/models/shapes.dart';
import 'package:fpaint/panels/tool.dart';

class ToolsPanel extends StatelessWidget {
  const ToolsPanel({
    super.key,
    required this.currentShapeType,
    required this.currentColor,
    required this.onShapeSelected,
    required this.onColorPicker,
  });
  final ShapeType currentShapeType;
  final Color currentColor;
  final Function(ShapeType) onShapeSelected;
  final VoidCallback onColorPicker;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.grey.shade200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Pencil
          ToolItem(
            name: 'Draw',
            icon: Icons.edit_outlined,
            isSelected: currentShapeType == ShapeType.pencil,
            onPressed: () => onShapeSelected(ShapeType.pencil),
          ),

          // Line
          ToolItem(
            name: 'Line',
            icon: Icons.line_axis,
            isSelected: currentShapeType == ShapeType.line,
            onPressed: () => onShapeSelected(ShapeType.line),
          ),

          // Rectangle
          ToolItem(
            name: 'Rectangle',
            icon: Icons.crop_square,
            isSelected: currentShapeType == ShapeType.rectangle,
            onPressed: () => onShapeSelected(ShapeType.rectangle),
          ),
          // Circle
          ToolItem(
            name: 'Circle',
            icon: Icons.circle_outlined,
            isSelected: currentShapeType == ShapeType.circle,
            onPressed: () => onShapeSelected(ShapeType.circle),
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
