import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/tools/tool_attributes_widget.dart';
import 'package:fpaint/panels/tools/tool_selector.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            spacing: minimal ? 2.0 : 4,
            runSpacing: minimal ? 2.0 : 4,
            alignment: WrapAlignment.center,
            children: getListOfTools(context, appModel),
          ),
          const Divider(
            color: Colors.black,
          ),
          Wrap(
            runSpacing: minimal ? 8.0 : 2,
            alignment: WrapAlignment.center,
            children: getWidgetForSelectedTool(context: context),
          ),
        ],
      ),
    );
  }

  Icon iconAndColor(context, isSelected, tool) {
    Color? color = isSelected ? Colors.blue : null;
    return Icon(tool, color: color);
  }

  List<Widget> getListOfTools(
    BuildContext context,
    final AppModel appModel,
  ) {
    final Tools selectedTool = appModel.selectedTool;

    final List<Widget> tools = [
      // Pencil
      ToolSelector(
        minimal: minimal,
        name: 'Pencil',
        image: iconAndColor(context, selectedTool == Tools.pencil, Icons.draw),
        isSelected: selectedTool == Tools.pencil,
        onPressed: () {
          appModel.selectedTool = Tools.pencil;
        },
      ),

      // Brush
      ToolSelector(
        minimal: minimal,
        name: 'Brush',
        image: iconAndColor(context, selectedTool == Tools.brush, Icons.brush),
        isSelected: selectedTool == Tools.brush,
        onPressed: () {
          appModel.selectedTool = Tools.brush;
        },
      ),

      // Line
      ToolSelector(
        minimal: minimal,
        name: 'Line',
        image:
            iconAndColor(context, selectedTool == Tools.line, Icons.line_axis),
        isSelected: selectedTool == Tools.line,
        onPressed: () {
          appModel.selectedTool = Tools.line;
        },
      ),

      // Rectangle
      ToolSelector(
        minimal: minimal,
        name: 'Rectangle',
        image: iconAndColor(
          context,
          selectedTool == Tools.rectangle,
          Icons.crop_square,
        ),
        isSelected: selectedTool == Tools.rectangle,
        onPressed: () {
          appModel.selectedTool = Tools.rectangle;
        },
      ),

      // Circle
      ToolSelector(
        minimal: minimal,
        name: 'Circle',
        image: iconAndColor(
          context,
          selectedTool == Tools.circle,
          Icons.circle_outlined,
        ),
        isSelected: selectedTool == Tools.circle,
        onPressed: () {
          appModel.selectedTool = Tools.circle;
        },
      ),

      // Paint Bucket
      ToolSelector(
        minimal: minimal,
        name: 'Paint Bucket',
        image: iconAndColor(
          context,
          selectedTool == Tools.fill,
          Icons.format_color_fill,
        ),
        isSelected: selectedTool == Tools.fill,
        onPressed: () {
          appModel.selectedTool = Tools.fill;
        },
      ),

      ToolSelector(
        minimal: minimal,
        name: 'Eraser',
        image: iconFromSvgAsset(
          'assets/icons/eraser.svg',
          selectedTool == Tools.eraser
              ? Colors.blue
              : IconTheme.of(context).color!,
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
          minimal: minimal,
          name: title,
          childLeft: IconButton(
            icon: const Icon(Icons.line_weight),
            color: Colors.grey.shade500,
            constraints: minimal ? const BoxConstraints() : null,
            padding: minimal ? EdgeInsets.zero : const EdgeInsets.all(8),
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
          childRight: minimal
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
          minimal: minimal,
          name: 'Brush Style',
          childLeft: IconButton(
            icon: const Icon(Icons.line_style_outlined),
            color: Colors.grey.shade500,
            constraints: minimal ? const BoxConstraints() : null,
            padding: minimal ? EdgeInsets.zero : const EdgeInsets.all(8),
            onPressed: () {
              showBrushStylePicker(
                context,
              );
            },
          ),
          childRight: minimal ? null : brushStyleSelection(appModel),
        ),
      );
    }

    // Brush color
    if (selectedTool.isSupported(ToolAttribute.colorOutline)) {
      widgets.add(
        ToolAttributeWidget(
          minimal: minimal,
          name: 'Brush Color',
          childLeft: colorPreviewWithTransparentPaper(
            minimal: minimal,
            color: appModel.brushColor,
            onPressed: () {
              showColorPicker(
                context: context,
                title: 'Brush Color',
                color: appModel.brushColor,
                onSelectedColor: (final Color color) =>
                    appModel.brushColor = color,
              );
            },
          ),
          childRight: minimal
              ? null
              : ColorSelector(
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
          minimal: minimal,
          name: 'Fill Color',
          childLeft: colorPreviewWithTransparentPaper(
            minimal: minimal,
            color: appModel.fillColor,
            onPressed: () {
              showColorPicker(
                context: context,
                title: 'Fill Color',
                color: appModel.brushColor,
                onSelectedColor: (final Color color) =>
                    appModel.fillColor = color,
              );
            },
          ),
          childRight: minimal
              ? null
              : ColorSelector(
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
          minimal: minimal,
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
          childRight: minimal
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
        minimal: minimal,
      ),
    );

    // Add a separator between each element
    if (!minimal) {
      List<Widget> separatedWidgets = [];
      for (int i = 0; i < widgets.length; i++) {
        separatedWidgets.add(widgets[i]);
        separatedWidgets.add(separator());
      }
      return separatedWidgets;
    }
    return widgets;
  }
}

Widget separator() {
  return const Divider(
    thickness: 1,
    height: 15,
    color: Colors.black,
  );
}
