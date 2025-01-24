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
  final Tools currentShapeType;
  final Function(Tools) onShapeSelected;

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
          return Container(
            constraints: const BoxConstraints(
              maxHeight: 400,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildTools(),
                Expanded(
                  child: buildAttributes(context, appModel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildTools() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Pencil
        ToolItem(
          name: 'Draw',
          icon: Icons.brush,
          isSelected: currentShapeType == Tools.draw,
          onPressed: () => onShapeSelected(Tools.draw),
        ),

        // Line
        ToolItem(
          name: 'Line',
          icon: Icons.line_axis,
          isSelected: currentShapeType == Tools.line,
          onPressed: () => onShapeSelected(Tools.line),
        ),

        // Rectangle
        ToolItem(
          name: 'Rectangle',
          icon: Icons.crop_square,
          isSelected: currentShapeType == Tools.rectangle,
          onPressed: () => onShapeSelected(Tools.rectangle),
        ),

        // Circle
        ToolItem(
          name: 'Circle',
          icon: Icons.circle_outlined,
          isSelected: currentShapeType == Tools.circle,
          onPressed: () => onShapeSelected(Tools.circle),
        ),

        ToolItem(
          name: 'Eraser',
          icon: Icons.cleaning_services,
          isSelected: currentShapeType == Tools.eraser,
          onPressed: () => onShapeSelected(Tools.eraser),
        ),
      ],
    );
  }

  Widget buildAttributes(final BuildContext context, final AppModel appModel) {
    List<Widget> widgets = [];

    // Stroke Weight
    if (currentShapeType.isSupported(ToolAttribute.brushSize)) {
      widgets.add(
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
      );
    }

    // Bruse Style
    if (currentShapeType.isSupported(ToolAttribute.brushStyle)) {
      widgets.add(
        adjustmentWidget(
          name: 'Brush Style',
          buttonIcon: Icons.line_style_outlined,
          buttonIconColor: Colors.black,
          onButtonPressed: () {},
          child: brushSelection(appModel),
        ),
      );
    }

    // Color Stroke
    if (currentShapeType.isSupported(ToolAttribute.colorOutline)) {
      widgets.add(
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
            onColorChanged: (Color color) => appModel.colorForStroke = color,
          ),
        ),
      );
    }

    // Color Fill
    if (currentShapeType.isSupported(ToolAttribute.colorFill)) {
      widgets.add(
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
            onColorChanged: (Color color) => appModel.colorForFill = color,
          ),
        ),
      );
    }

    return SizedBox(
      width: 360,
      child: ListView.separated(
        itemCount: widgets.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) => widgets[index],
      ),
    );
  }

  bool shapeSupportsFill(final Tools type, final ToolAttribute attribute) {
    final Set<ToolAttribute>? tool = toolsSupportedAttributes[type];
    return tool!.contains(attribute);
  }

  Widget adjustmentWidget({
    required String name,
    required IconData buttonIcon,
    required Color buttonIconColor,
    required VoidCallback onButtonPressed,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(buttonIcon),
            onPressed: onButtonPressed,
            color: buttonIconColor,
            tooltip: name,
          ),
          Expanded(
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
