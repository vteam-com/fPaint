import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/tools/tool_attributes_widget.dart';
import 'package:fpaint/panels/tools/tool_selector.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/color_picker.dart';
import 'package:fpaint/widgets/svg_icon.dart';
import 'package:provider/provider.dart';

/// Represents a panel that displays tools for the application.
/// The ToolsPanel is a stateless widget that displays a set of tools
/// that the user can interact with to perform various actions in the
/// application. It includes a list of tools, as well as any associated
/// attributes or settings for the selected tool.
class ToolsPanel extends StatelessWidget {
  const ToolsPanel({
    super.key,
    required this.currentShapeType,
    required this.onShapeSelected,
    required this.minimal,
  });
  final Tools currentShapeType;
  final Function(Tools) onShapeSelected;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(
      builder: (
        final BuildContext context,
        final AppModel appModel,
        final Widget? child,
      ) {
        if (minimal) {
          return slimLayout(context);
        } else {
          return largeLayout(context);
        }
      },
    );
  }

  Widget slimLayout(context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        spacing: 8,
        children: [
          ...getListOfTools(context),
          // Divider
          //
          const Divider(
            thickness: 1,
            height: 1,
            color: Colors.grey,
          ),

          ...getWidgetForSelectedTool(
            context: context,
            slim: true,
          ),
        ],
      ),
    );
  }

  Widget largeLayout(context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        spacing: 8,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: getListOfTools(context),
          ),
          // Divider
          //
          const Divider(
            thickness: 6,
            height: 10,
          ),

          ...getWidgetForSelectedTool(
            context: context,
            slim: false,
          ),
        ],
      ),
    );
  }

  List<Widget> getListOfTools(BuildContext context) {
    final List<Widget> tools = [
      // Pencil
      ToolSelector(
        name: 'Draw',
        image: Icon(Icons.brush, color: IconTheme.of(context).color!),
        isSelected: currentShapeType == Tools.draw,
        onPressed: () => onShapeSelected(Tools.draw),
      ),

      // Line
      ToolSelector(
        name: 'Line',
        image: Icon(Icons.line_axis, color: IconTheme.of(context).color!),
        isSelected: currentShapeType == Tools.line,
        onPressed: () => onShapeSelected(Tools.line),
      ),

      // Rectangle
      ToolSelector(
        name: 'Rectangle',
        image: Icon(Icons.crop_square, color: IconTheme.of(context).color!),
        isSelected: currentShapeType == Tools.rectangle,
        onPressed: () => onShapeSelected(Tools.rectangle),
      ),

      // Circle
      ToolSelector(
        name: 'Circle',
        image: Icon(Icons.circle_outlined, color: IconTheme.of(context).color!),
        isSelected: currentShapeType == Tools.circle,
        onPressed: () => onShapeSelected(Tools.circle),
      ),

      // Paint Bucket
      ToolSelector(
        name: 'Paint Bucket',
        image:
            Icon(Icons.format_color_fill, color: IconTheme.of(context).color!),
        isSelected: currentShapeType == Tools.fill,
        onPressed: () => onShapeSelected(Tools.fill),
      ),

      ToolSelector(
        name: 'Eraser',
        image: iconFromSvgAsset(
          'assets/icons/eraser.svg',
          IconTheme.of(context).color!,
        ),
        isSelected: currentShapeType == Tools.eraser,
        onPressed: () => onShapeSelected(Tools.eraser),
      ),
    ];
    return tools;
  }

  List<Widget> getWidgetForSelectedTool({
    required BuildContext context,
    required bool slim,
  }) {
    List<Widget> widgets = [];
    final appModel = AppModel.get(context, listen: true);

    // Stroke Weight
    if (currentShapeType.isSupported(ToolAttribute.brushSize)) {
      widgets.add(
        ToolAttributeWidget(
          name: 'Brush Size',
          buttonIcon: Icons.line_weight,
          buttonIconColor: Colors.grey.shade500,
          onButtonPressed: () {
            showBrushSizePicker(context, appModel.brusSize,
                (final double newValue) {
              appModel.brusSize = newValue;
            });
          },
          child: slim
              ? null
              : BrushSizePicker(
                  value: appModel.brusSize,
                  onChanged: (value) {
                    appModel.brusSize = value;
                  },
                ),
        ),
      );
    }

    // Bruse Style
    if (currentShapeType.isSupported(ToolAttribute.brushStyle)) {
      widgets.add(
        ToolAttributeWidget(
          name: 'Brush Style',
          buttonIcon: Icons.line_style_outlined,
          buttonIconColor: Colors.grey.shade500,
          onButtonPressed: () {
            showBrushStylePicker(context);
          },
          child: slim ? null : brushStyleSelection(appModel),
        ),
      );
    }

    // Color Stroke
    if (currentShapeType.isSupported(ToolAttribute.colorOutline)) {
      widgets.add(
        ToolAttributeWidget(
          name: 'Brush Color',
          buttonIcon: Icons.water_drop_outlined,
          buttonIconColor: appModel.brushColor,
          onButtonPressed: () => showColorPicker(
            context: context,
            title: 'Brush',
            color: appModel.brushColor,
            onSelectedColor: (final Color color) => appModel.brushColor = color,
          ),
          transparentPaper: true,
          child: slim
              ? null
              : MyColorPicker(
                  color: appModel.brushColor,
                  onColorChanged: (Color color) => appModel.brushColor = color,
                ),
        ),
      );
    }

    // Color Fill
    if (currentShapeType.isSupported(ToolAttribute.colorFill)) {
      widgets.add(
        ToolAttributeWidget(
          name: 'Fill Color',
          buttonIcon: Icons.water_drop,
          buttonIconColor: appModel.fillColor,
          onButtonPressed: () => showColorPicker(
            context: context,
            title: 'Fill',
            color: appModel.fillColor,
            onSelectedColor: (final Color color) => appModel.fillColor = color,
          ),
          transparentPaper: true,
          child: slim
              ? null
              : MyColorPicker(
                  color: appModel.fillColor,
                  onColorChanged: (Color color) => appModel.fillColor = color,
                ),
        ),
      );
    }
    return widgets;
  }
}
