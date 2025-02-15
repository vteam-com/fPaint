import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/panels/tools/tool_attributes_widget.dart';
import 'package:fpaint/panels/tools/tool_selector.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/svg_icon.dart';
import 'package:fpaint/widgets/tolerance_picker.dart';
import 'package:fpaint/widgets/top_colors.dart';
import 'package:material_symbols_icons/symbols.dart';

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
    final ActionType selectedTool = appModel.selectedAction;

    final List<Widget> tools = [
      // Pencil
      ToolSelector(
        minimal: minimal,
        name: 'Pencil',
        image: iconAndColor(
          context,
          selectedTool == ActionType.pencil,
          Icons.draw,
        ),
        isSelected: selectedTool == ActionType.pencil,
        onPressed: () {
          appModel.selectedAction = ActionType.pencil;
        },
      ),

      // Brush
      ToolSelector(
        minimal: minimal,
        name: 'Brush',
        image: iconAndColor(
          context,
          selectedTool == ActionType.brush,
          Icons.brush,
        ),
        isSelected: selectedTool == ActionType.brush,
        onPressed: () {
          appModel.selectedAction = ActionType.brush;
        },
      ),

      // Line
      ToolSelector(
        minimal: minimal,
        name: 'Line',
        image: iconAndColor(
          context,
          selectedTool == ActionType.line,
          Icons.line_axis,
        ),
        isSelected: selectedTool == ActionType.line,
        onPressed: () {
          appModel.selectedAction = ActionType.line;
        },
      ),

      // Rectangle
      ToolSelector(
        minimal: minimal,
        name: 'Rectangle',
        image: iconAndColor(
          context,
          selectedTool == ActionType.rectangle,
          Icons.crop_square,
        ),
        isSelected: selectedTool == ActionType.rectangle,
        onPressed: () {
          appModel.selectedAction = ActionType.rectangle;
        },
      ),

      // Circle
      ToolSelector(
        minimal: minimal,
        name: 'Circle',
        image: iconAndColor(
          context,
          selectedTool == ActionType.circle,
          Icons.circle_outlined,
        ),
        isSelected: selectedTool == ActionType.circle,
        onPressed: () {
          appModel.selectedAction = ActionType.circle;
        },
      ),

      // Paint Bucket
      ToolSelector(
        minimal: minimal,
        name: 'Paint Bucket',
        image: iconAndColor(
          context,
          selectedTool == ActionType.fill,
          Icons.format_color_fill,
        ),
        isSelected: selectedTool == ActionType.fill,
        onPressed: () {
          appModel.selectedAction = ActionType.fill;
        },
      ),

      ToolSelector(
        minimal: minimal,
        name: 'Eraser',
        image: iconFromSvgAsset(
          'assets/icons/eraser.svg',
          selectedTool == ActionType.eraser
              ? Colors.blue
              : IconTheme.of(context).color!,
        ),
        isSelected: selectedTool == ActionType.eraser,
        onPressed: () {
          appModel.selectedAction = ActionType.eraser;
        },
      ),

      ToolSelector(
        minimal: minimal,
        name: 'Selector',
        image: iconAndColor(
          context,
          selectedTool == ActionType.selector,
          Symbols.select,
        ),
        isSelected: selectedTool == ActionType.selector,
        onPressed: () {
          appModel.selectedAction = ActionType.selector;
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
    final selectedTool = appModel.selectedAction;
    final String title = appModel.selectedAction == ActionType.pencil
        ? 'Pencil Size'
        : 'Brush Size';
    final double min = appModel.selectedAction == ActionType.pencil ? 1 : 0.1;
    final double max = 100;

    // Selector options
    if (selectedTool.isSupported(ActionOptions.selectorOptions)) {
      widgets.add(
        ToolAttributeWidget(
          minimal: minimal,
          name: 'Selector',
          childRight: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //
              // Selection using Rectangle
              //
              ToolSelector(
                minimal: minimal,
                name: 'Rectangle',
                image: iconAndColor(
                  context,
                  appModel.selector.mode == SelectorMode.rectangle,
                  Icons.highlight_alt,
                ),
                isSelected: appModel.selector.mode == SelectorMode.rectangle,
                onPressed: () {
                  appModel.selector.mode = SelectorMode.rectangle;
                  appModel.update();
                },
              ),
              //
              // Selection using Circle
              //
              ToolSelector(
                minimal: minimal,
                name: 'Circle',
                image: iconAndColor(
                  context,
                  appModel.selector.mode == SelectorMode.circle,
                  Symbols.lasso_select,
                ),
                isSelected: appModel.selector.mode == SelectorMode.circle,
                onPressed: () {
                  appModel.selector.mode = SelectorMode.circle;
                  appModel.update();
                },
              ),
              //
              // Selection using magic wand
              //
              ToolSelector(
                minimal: minimal,
                name: 'Detect',
                image: iconAndColor(
                  context,
                  appModel.selector.mode == SelectorMode.wand,
                  Icons.auto_fix_high_outlined,
                ),
                isSelected: appModel.selector.mode == SelectorMode.wand,
                onPressed: () {
                  appModel.selector.mode = SelectorMode.wand;
                  appModel.update();
                },
              ),

              //
              // Cancel/Hide Selection tool
              //
              if (appModel.selector.isVisible)
                ToolSelector(
                  minimal: minimal,
                  name: 'Cancel',
                  image: iconAndColor(
                    context,
                    false,
                    Symbols.remove_selection,
                  ),
                  isSelected: false,
                  onPressed: () {
                    appModel.selector.clear();
                    appModel.update();
                  },
                ),
            ],
          ),
        ),
      );
    }

    // Brush Size
    if (selectedTool.isSupported(ActionOptions.brushSize)) {
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
    if (selectedTool.isSupported(ActionOptions.brushStyle)) {
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
    if (selectedTool.isSupported(ActionOptions.brushColor)) {
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

    // Fill Color
    if (selectedTool.isSupported(ActionOptions.colorFill)) {
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
                color: appModel.fillColor,
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
    if (selectedTool.isSupported(ActionOptions.tolerance)) {
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

    // Top colors
    if (selectedTool.isSupported(ActionOptions.topColors)) {
      widgets.add(
        TopColors(
          colorUsages: appModel.topColors,
          onRefresh: () => appModel.evaluatTopColor(),
          onColorPicked: (color) {
            (appModel.selectedAction == ActionType.rectangle ||
                    appModel.selectedAction == ActionType.circle ||
                    appModel.selectedAction == ActionType.fill)
                ? appModel.fillColor = color
                : appModel.brushColor = color;
          },
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
