import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/tool.dart';
import 'package:fpaint/widgets/color_picker.dart';
import 'package:provider/provider.dart';

class ToolsPanel extends StatelessWidget {
  const ToolsPanel({
    super.key,
    required this.currentShapeType,
    required this.onShapeSelected,
  });
  final ShapeType currentShapeType;
  final Function(ShapeType) onShapeSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
      child: Consumer<AppModel>(
        builder: (
          final BuildContext context,
          final AppModel appModel,
          Widget? child,
        ) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
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
                  ],
                ),

                divider(),

                // Stroke Weight
                adjustmentWidget(
                  name: 'Stroke Style',
                  buttonIcon: Icons.line_weight,
                  buttonIconColor: Colors.black,
                  onButtonPressed: () {},
                  child: Slider(
                    value: appModel.lineWeight,
                    min: 1,
                    max: 100,
                    divisions: 100,
                    label: appModel.lineWeight.round().toString(),
                    onChanged: (double value) {
                      appModel.lineWeight = value;
                    },
                  ),
                ),

                // Stroke Style
                if (currentShapeType == ShapeType.line)
                  if (currentShapeType == ShapeType.line)
                    adjustmentWidget(
                      name: 'Brush Style',
                      buttonIcon: Icons.line_style_outlined,
                      buttonIconColor: Colors.black,
                      onButtonPressed: () {},
                      child: brushSelection(appModel),
                    ),

                divider(),

                // Color Stroke
                adjustmentWidget(
                  name: 'Stroke Color',
                  buttonIcon: Icons.water_drop_outlined,
                  buttonIconColor: appModel.colorForStroke,
                  onButtonPressed: () => showColorPicker(
                    context: context,
                    title: 'Stroke',
                    color: appModel.colorForStroke,
                    onSelectedColor: (final Color color) =>
                        appModel.colorForStroke = color,
                  ),
                  child: MyColorPicker(
                    color: appModel.colorForStroke,
                    onColorChanged: (Color color) =>
                        appModel.colorForStroke = color,
                  ),
                ),

                divider(),

                // Color Fill
                if (shapeSupportsFill(currentShapeType))
                  adjustmentWidget(
                    name: 'Fill Color',
                    buttonIcon: Icons.water_drop,
                    buttonIconColor: appModel.colorForFill,
                    onButtonPressed: () => showColorPicker(
                      context: context,
                      title: 'Fill',
                      color: appModel.colorForFill,
                      onSelectedColor: (final Color color) =>
                          appModel.colorForFill = color,
                    ),
                    child: MyColorPicker(
                      color: appModel.colorForFill,
                      onColorChanged: (Color color) =>
                          appModel.colorForFill = color,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget divider() {
    return Container(
      margin: EdgeInsets.all(8),
      width: 340,
      height: 1,
      color: Colors.grey,
    );
  }

  bool shapeSupportsFill(final ShapeType type) {
    switch (type) {
      case ShapeType.pencil:
      case ShapeType.line:
        return false;
      default:
        return true;
    }
  }

  Widget adjustmentWidget({
    required String name,
    required IconData buttonIcon,
    required Color buttonIconColor,
    required VoidCallback onButtonPressed,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(buttonIcon),
            onPressed: onButtonPressed,
            color: buttonIconColor,
            tooltip: name,
          ),
          SizedBox(
            width: 300,
            child: child,
          ),
        ],
      ),
    );
  }

  void showColorPicker({
    required final BuildContext context,
    required final String title,
    required final Color color,
    required final ValueChanged<Color> onSelectedColor,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ColorPicker(
              color: color,
              onColorChanged: (Color color) {
                onSelectedColor(color);
              },
              pickersEnabled: {
                ColorPickerType.wheel: true,
                ColorPickerType.primary: true,
                ColorPickerType.accent: true,
              },
              showColorCode: true,
            ),
          ),
        );
      },
    );
  }
}
