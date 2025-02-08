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
        crossAxisAlignment:
            minimal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Wrap(children: getListOfTools(context, appModel)),
          Wrap(
            runSpacing: minimal ? 8.0 : 0,
            alignment: WrapAlignment.center,
            children: getWidgetForSelectedTool(context: context),
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
        minimal: minimal,
        name: 'Pencil',
        image: Icon(Icons.draw, color: IconTheme.of(context).color!),
        isSelected: selectedTool == Tools.pencil,
        onPressed: () {
          appModel.selectedTool = Tools.pencil;
        },
      ),

      // Brush
      ToolSelector(
        minimal: minimal,
        name: 'Brush',
        image: Icon(Icons.brush, color: IconTheme.of(context).color!),
        isSelected: selectedTool == Tools.brush,
        onPressed: () {
          appModel.selectedTool = Tools.brush;
        },
      ),

      // Line
      ToolSelector(
        minimal: minimal,
        name: 'Line',
        image: Icon(Icons.line_axis, color: IconTheme.of(context).color!),
        isSelected: selectedTool == Tools.line,
        onPressed: () {
          appModel.selectedTool = Tools.line;
        },
      ),

      // Rectangle
      ToolSelector(
        minimal: minimal,
        name: 'Rectangle',
        image: Icon(Icons.crop_square, color: IconTheme.of(context).color!),
        isSelected: selectedTool == Tools.rectangle,
        onPressed: () {
          appModel.selectedTool = Tools.rectangle;
        },
      ),

      // Circle
      ToolSelector(
        minimal: minimal,
        name: 'Circle',
        image: Icon(Icons.circle_outlined, color: IconTheme.of(context).color!),
        isSelected: selectedTool == Tools.circle,
        onPressed: () {
          appModel.selectedTool = Tools.circle;
        },
      ),

      // Paint Bucket
      ToolSelector(
        minimal: minimal,
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
        minimal: minimal,
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
        separatedWidgets.add(separator());
        separatedWidgets.add(widgets[i]);
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
