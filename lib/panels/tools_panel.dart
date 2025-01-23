import 'package:flutter/material.dart';
import 'package:fpaint/models/shapes.dart';
import 'package:fpaint/panels/tool.dart';

class ToolsPanel extends StatelessWidget {
  const ToolsPanel({
    super.key,
    required this.currentShapeType,
    required this.colorFill,
    required this.colorBorder,
    required this.onShapeSelected,
    required this.onColorPickerFill,
    required this.onColorPickerBorder,
  });
  final ShapeType currentShapeType;
  final Color colorFill;
  final Color colorBorder;
  final Function(ShapeType) onShapeSelected;
  final VoidCallback onColorPickerFill;
  final VoidCallback onColorPickerBorder;

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

          // Color Fill
          IconButton(
            icon: Icon(Icons.water_drop),
            onPressed: onColorPickerFill,
            color: colorFill,
            tooltip: 'Fill Color',
          ),

          // Color Border
          IconButton(
            icon: Icon(Icons.water_drop_outlined),
            onPressed: onColorPickerBorder,
            color: colorBorder,
            tooltip: 'Border Color',
          ),
        ],
      ),
    );
  }
}
