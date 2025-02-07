import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/tools/tool_attributes_widget.dart';
import 'package:fpaint/panels/tools/tool_selector.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/color_picker.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/svg_icon.dart';
import 'package:fpaint/widgets/tolerance_picker.dart';
import 'package:fpaint/widgets/top_colors.dart';

/// Represents a panel that displays tools for the application.
/// The ToolsPanel is a stateless widget that displays a set of tools
/// that the user can interact with to perform various actions in the
/// application. It includes a list of tools, as well as any associated
/// attributes or settings for the selected tool.
class ToolsPanel extends StatelessWidget {
  const ToolsPanel({
    super.key,
    required this.minimal,
  });

  final bool minimal;

  @override
  Widget build(BuildContext context) {
    AppModel appModel = AppModel.of(context, listen: true);
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        spacing: 8,
        children: [
          Wrap(children: getListOfTools(context, appModel)),
          ...getWidgetForSelectedTool(
            context: context,
            slim: minimal,
          ),
        ],
      ),
    );
  }

  List<Widget> getListOfTools(
    BuildContext context,
    final AppModel appModel,
  ) {
    final selectedTool = appModel.selectedTool;
    final List<Widget> tools = [
      // Brush
      ToolSelector(
        name: 'Pencil',
        image: Icon(Icons.draw, color: IconTheme.of(context).color!),
        isSelected: selectedTool == Tools.pencil,
        onPressed: () {
          appModel.selectedTool = Tools.pencil;
        },
      ),

      // Brush
      ToolSelector(
        name: 'Brush',
        image: Icon(Icons.brush, color: IconTheme.of(context).color!),
        isSelected: selectedTool == Tools.brush,
        onPressed: () {
          appModel.selectedTool = Tools.brush;
        },
      ),

      // Line
      ToolSelector(
        name: 'Line',
        image: Icon(Icons.line_axis, color: IconTheme.of(context).color!),
        isSelected: selectedTool == Tools.line,
        onPressed: () {
          appModel.selectedTool = Tools.line;
        },
      ),

      // Rectangle
      ToolSelector(
        name: 'Rectangle',
        image: Icon(Icons.crop_square, color: IconTheme.of(context).color!),
        isSelected: selectedTool == Tools.rectangle,
        onPressed: () {
          appModel.selectedTool = Tools.rectangle;
        },
      ),

      // Circle
      ToolSelector(
        name: 'Circle',
        image: Icon(Icons.circle_outlined, color: IconTheme.of(context).color!),
        isSelected: selectedTool == Tools.circle,
        onPressed: () {
          appModel.selectedTool = Tools.circle;
        },
      ),

      // Paint Bucket
      ToolSelector(
        name: 'Paint Bucket',
        image: Icon(
          Icons.format_color_fill,
          color: IconTheme.of(context).color!,
        ),
        isSelected: selectedTool == Tools.fill,
        onPressed: () {
          appModel.selectedTool = Tools.fill;
        },
      ),

      ToolSelector(
        name: 'Eraser',
        image: iconFromSvgAsset(
          'assets/icons/eraser.svg',
          IconTheme.of(context).color!,
        ),
        isSelected: selectedTool == Tools.eraser,
        onPressed: () {
          appModel.selectedTool = Tools.eraser;
        },
      ),
    ];
    return tools;
  }

  List<Widget> getWidgetForSelectedTool({
    required BuildContext context,
    required bool slim,
  }) {
    List<Widget> widgets = [];
    final appModel = AppModel.of(context, listen: true);
    final selectedTool = appModel.selectedTool;
    final String title =
        appModel.selectedTool == Tools.pencil ? 'Pencil Size' : 'Brush Size';
    final double min = appModel.selectedTool == Tools.pencil ? 1 : 0.1;
    final double max = 100;

    // Stroke Weight
    if (selectedTool.isSupported(ToolAttribute.strokeSize)) {
      widgets.add(
        ToolAttributeWidget(
          name: title,
          childLeft: IconButton(
            icon: const Icon(Icons.line_weight),
            color: Colors.grey.shade500,
            onPressed: () {
              showBrushSizePicker(
                context: context,
                title: title,
                value: appModel.brusSize,
                min: min,
                max: max,
                onChanged: (final double newValue) {
                  appModel.brusSize = newValue;
                },
              );
            },
          ),
          childRight: slim
              ? null
              : BrushSizePicker(
                  title: title,
                  value: appModel.brusSize,
                  min: min,
                  max: max,
                  onChanged: (value) {
                    appModel.brusSize = value;
                  },
                ),
        ),
      );
    }

    // Brush Style
    if (selectedTool.isSupported(ToolAttribute.brushStyle)) {
      widgets.add(
        ToolAttributeWidget(
          name: 'Brush Style',
          childLeft: IconButton(
            icon: const Icon(Icons.line_style_outlined),
            color: Colors.grey.shade500,
            onPressed: () {
              showBrushSizePicker(
                context: context,
                title: 'Brush Style',
                min: min,
                max: max,
                value: appModel.brusSize,
                onChanged: (final double newValue) {
                  appModel.brusSize = newValue;
                },
              );
            },
          ),
          childRight: slim ? null : brushStyleSelection(appModel),
        ),
      );
    }

    // Brush color
    if (selectedTool.isSupported(ToolAttribute.colorOutline)) {
      widgets.add(
        ToolAttributeWidget(
          name: 'Brush Color',
          childLeft: ColorPreview(
            colorUsed: ColorUsage(appModel.brushColor, 1),
            onPressed: () {
              showColorPicker(
                context: context,
                title: 'Brush',
                color: appModel.brushColor,
                onSelectedColor: (final Color color) =>
                    appModel.brushColor = color,
              );
            },
          ),
          childRight: slim
              ? null
              : MyColorPicker(
                  color: appModel.brushColor,
                  onColorChanged: (Color color) => appModel.brushColor = color,
                ),
        ),
      );
    }

    // Color Fill
    if (selectedTool.isSupported(ToolAttribute.colorFill)) {
      widgets.add(
        ToolAttributeWidget(
          name: 'Fill Color',
          childLeft: ColorPreview(
            colorUsed: ColorUsage(appModel.fillColor, 1),
            onPressed: () {
              showColorPicker(
                context: context,
                title: 'Fill',
                color: appModel.brushColor,
                onSelectedColor: (final Color color) =>
                    appModel.fillColor = color,
              );
            },
          ),
          childRight: slim
              ? null
              : MyColorPicker(
                  color: appModel.fillColor,
                  onColorChanged: (Color color) => appModel.fillColor = color,
                ),
        ),
      );
    }

    // Fill Color Tolerance
    if (selectedTool.isSupported(ToolAttribute.tolerance)) {
      widgets.add(
        ToolAttributeWidget(
          name: 'Color Tolerance',
          childLeft: IconButton(
            icon: const Icon(Icons.support),
            color: Colors.grey.shade500,
            onPressed: () {
              showTolerancePicker(context, appModel.tolerance,
                  (final int newValue) {
                appModel.tolerance = newValue;
              });
            },
          ),
          childRight: slim
              ? null
              : TolerancePicker(
                  value: appModel.tolerance,
                  onChanged: (value) {
                    appModel.tolerance = value;
                  },
                ),
        ),
      );
    }

    widgets.add(
      TopColors(
        colorUsages: appModel.topColors,
        onRefresh: () => appModel.evaluatTopColor(),
        showTitle: !minimal,
      ),
    );

    // Add a separator between each element
    List<Widget> separatedWidgets = [];
    for (int i = 0; i < widgets.length; i++) {
      separatedWidgets.add(separator());
      separatedWidgets.add(widgets[i]);
    }
    return separatedWidgets;
  }
}

Widget separator() {
  return const Divider(
    thickness: 1,
    height: 15,
    color: Colors.black,
  );
}
