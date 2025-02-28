import 'package:flutter/material.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/panels/tools/tool_attributes_widget.dart';
import 'package:fpaint/panels/tools/tool_panel_picker.dart';
import 'package:fpaint/providers/app_provider.dart';
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
  Widget build(final BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Wrap(
            spacing: minimal ? 2.0 : 4,
            runSpacing: minimal ? 2.0 : 4,
            alignment: WrapAlignment.center,
            children: getListOfTools(context),
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

  Icon iconAndColor(final bool isSelected, final IconData tool) {
    final Color? color = isSelected ? Colors.blue : null;
    return Icon(tool, color: color);
  }

  List<Widget> getListOfTools(
    final BuildContext context,
  ) {
    final AppProvider appProvider = AppProvider.of(context);
    final ActionType selectedTool = appProvider.selectedAction;

    final List<Widget> tools = <Widget>[
      // Pencil
      ToolPanelPicker(
        minimal: minimal,
        name: 'Pencil',
        image: iconAndColor(
          selectedTool == ActionType.pencil,
          Icons.draw,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.pencil;
        },
      ),

      // Brush
      ToolPanelPicker(
        minimal: minimal,
        name: 'Brush',
        image: iconAndColor(
          selectedTool == ActionType.brush,
          Icons.brush,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.brush;
        },
      ),

      // Line
      ToolPanelPicker(
        minimal: minimal,
        name: 'Line',
        image: iconAndColor(
          selectedTool == ActionType.line,
          Icons.line_axis,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.line;
        },
      ),

      // Rectangle
      ToolPanelPicker(
        minimal: minimal,
        name: 'Rectangle',
        image: iconAndColor(
          selectedTool == ActionType.rectangle,
          Icons.crop_square,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.rectangle;
        },
      ),

      // Circle
      ToolPanelPicker(
        minimal: minimal,
        name: 'Circle',
        image: iconAndColor(
          selectedTool == ActionType.circle,
          Icons.circle_outlined,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.circle;
        },
      ),

      // Paint Bucket
      ToolPanelPicker(
        minimal: minimal,
        name: 'Paint Bucket',
        image: iconAndColor(
          selectedTool == ActionType.fill,
          Icons.format_color_fill,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.fill;
        },
      ),

      ToolPanelPicker(
        minimal: minimal,
        name: 'Eraser',
        image: iconFromSvgAsset(
          'assets/icons/eraser.svg',
          selectedTool == ActionType.eraser
              ? Colors.blue
              : IconTheme.of(context).color!,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.eraser;
        },
      ),

      ToolPanelPicker(
        minimal: minimal,
        name: 'Selector',
        image: iconAndColor(
          selectedTool == ActionType.selector,
          Symbols.select,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.selector;
        },
      ),
    ];
    return tools;
  }

  List<Widget> getWidgetForSelectedTool({
    required final BuildContext context,
  }) {
    final List<Widget> widgets = <Widget>[];
    final AppProvider appProvider = AppProvider.of(context, listen: true);
    final LayersProvider layers = LayersProvider.of(context);
    final ActionType selectedTool = appProvider.selectedAction;
    final String title = appProvider.selectedAction == ActionType.pencil
        ? 'Pencil Size'
        : 'Brush Size';
    final double min =
        appProvider.selectedAction == ActionType.pencil ? 1 : 0.1;
    final double max = 100;

    // Selector options
    if (selectedTool.isSupported(ActionOptions.selectorOptions)) {
      widgets.add(
        ToolAttributeWidget(
          minimal: minimal,
          name: 'Selector',
          childRight: Wrap(
            alignment: WrapAlignment.center,
            children: <Widget>[
              //
              // Selection using Rectangle
              //
              ToolPanelPicker(
                minimal: minimal,
                name: 'Rectangle',
                image: iconAndColor(
                  appProvider.selector.mode == SelectorMode.rectangle,
                  Icons.highlight_alt,
                ),
                onPressed: () {
                  appProvider.selector.mode = SelectorMode.rectangle;
                  appProvider.update();
                },
              ),
              //
              // Selection using Circle
              //
              ToolPanelPicker(
                minimal: minimal,
                name: 'Circle',
                image: iconAndColor(
                  appProvider.selector.mode == SelectorMode.circle,
                  Symbols.lasso_select,
                ),
                onPressed: () {
                  appProvider.selector.mode = SelectorMode.circle;
                  appProvider.update();
                },
              ),
              //
              // Selection using Drawing
              //
              ToolPanelPicker(
                minimal: minimal,
                name: 'Lasso',
                image: iconFromSvgAsset(
                  'assets/icons/lasso.svg',
                  appProvider.selector.mode == SelectorMode.lasso
                      ? Colors.blue
                      : IconTheme.of(context).color!,
                ),
                onPressed: () {
                  appProvider.selector.mode = SelectorMode.lasso;
                  appProvider.update();
                },
              ),
              //
              // Selection using magic wand
              //
              ToolPanelPicker(
                minimal: minimal,
                name: 'Magic',
                image: iconAndColor(
                  appProvider.selector.mode == SelectorMode.wand,
                  Icons.auto_fix_high_outlined,
                ),
                onPressed: () {
                  appProvider.selector.mode = SelectorMode.wand;
                  appProvider.update();
                },
              ),
              if (appProvider.selector.mode == SelectorMode.wand)
                ToolAttributeWidget(
                  minimal: minimal,
                  name: 'Color Tolerance',
                  childLeft: IconButton(
                    icon: const Icon(Icons.support),
                    color: Colors.grey.shade500,
                    onPressed: () {
                      showTolerancePicker(context, appProvider.tolerance,
                          (final int newValue) {
                        appProvider.tolerance = newValue;
                      });
                    },
                  ),
                  childRight: minimal
                      ? null
                      : TolerancePicker(
                          value: appProvider.tolerance,
                          onChanged: (final int value) {
                            appProvider.tolerance = value;
                          },
                        ),
                ),

              if (appProvider.selector.isVisible) const Divider(),
              //
              // Sub=Selector options Repace/Add/Remove/Invert/Cancel
              //
              if (appProvider.selector.isVisible)
                ToolPanelPicker(
                  minimal: minimal,
                  name: 'Replace',
                  image: iconFromSvgAssetSelected(
                    'assets/icons/selector_replace.svg',
                    appProvider.selector.math == SelectorMath.replace,
                  ),
                  onPressed: () {
                    appProvider.selector.math = SelectorMath.replace;
                    appProvider.update();
                  },
                ),
              if (appProvider.selector.isVisible)
                ToolPanelPicker(
                  minimal: minimal,
                  name: 'Add',
                  image: iconFromSvgAssetSelected(
                    'assets/icons/selector_add.svg',
                    appProvider.selector.math == SelectorMath.add,
                  ),
                  onPressed: () {
                    appProvider.selector.math = SelectorMath.add;
                    appProvider.update();
                  },
                ),
              if (appProvider.selector.isVisible)
                ToolPanelPicker(
                  minimal: minimal,
                  name: 'Remove',
                  image: iconFromSvgAssetSelected(
                    'assets/icons/selector_remove.svg',
                    appProvider.selector.math == SelectorMath.remove,
                  ),
                  onPressed: () {
                    appProvider.selector.math = SelectorMath.remove;
                    appProvider.update();
                  },
                ),
              if (appProvider.selector.isVisible) const Divider(),
              if (appProvider.selector.isVisible)
                ToolPanelPicker(
                  minimal: minimal,
                  name: 'Invert',
                  image: iconFromSvgAssetSelected(
                    'assets/icons/selector_invert.svg',
                    false,
                  ),
                  onPressed: () {
                    appProvider.selector.invert(
                      Rect.fromLTWH(
                        0,
                        0,
                        layers.size.width,
                        layers.size.height,
                      ),
                    );
                    appProvider.update();
                  },
                ),
              if (appProvider.selector.isVisible)
                ToolPanelPicker(
                  minimal: minimal,
                  name: 'Cancel',
                  image: iconAndColor(
                    false,
                    Symbols.remove_selection,
                  ),
                  onPressed: () {
                    appProvider.selector.clear();
                    appProvider.update();
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
                value: appProvider.brushSize,
                min: min,
                max: max,
                onChanged: (final double newValue) {
                  appProvider.brushSize = newValue;
                },
              );
            },
          ),
          childRight: minimal
              ? null
              : BrushSizePicker(
                  title: title,
                  value: appProvider.brushSize,
                  min: min,
                  max: max,
                  onChanged: (final double value) {
                    appProvider.brushSize = value;
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
                appProvider.brushStyle,
                (final BrushStyle selectedBrushStyle) =>
                    appProvider.brushStyle = selectedBrushStyle,
              );
            },
          ),
          childRight: minimal
              ? null
              : brushStyleDropDown(
                  appProvider.brushStyle,
                  (final BrushStyle selectedBrushStyle) =>
                      appProvider.brushStyle = selectedBrushStyle,
                ),
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
            color: appProvider.brushColor,
            onPressed: () {
              showColorPicker(
                context: context,
                title: 'Brush Color',
                color: appProvider.brushColor,
                onSelectedColor: (final Color color) =>
                    appProvider.brushColor = color,
              );
            },
          ),
          childRight: minimal
              ? null
              : ColorSelector(
                  color: appProvider.brushColor,
                  onColorChanged: (final Color color) =>
                      appProvider.brushColor = color,
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
            color: appProvider.fillColor,
            onPressed: () {
              showColorPicker(
                context: context,
                title: 'Fill Color',
                color: appProvider.fillColor,
                onSelectedColor: (final Color color) =>
                    appProvider.fillColor = color,
              );
            },
          ),
          childRight: minimal
              ? null
              : ColorSelector(
                  color: appProvider.fillColor,
                  onColorChanged: (final Color color) =>
                      appProvider.fillColor = color,
                ),
        ),
      );
    }

    // Color Tolerance used by Fill and Magic wand
    if (selectedTool.isSupported(ActionOptions.tolerance)) {
      widgets.add(
        ToolAttributeWidget(
          minimal: minimal,
          name: 'Color Tolerance',
          childLeft: IconButton(
            icon: const Icon(Icons.support),
            color: Colors.grey.shade500,
            onPressed: () {
              showTolerancePicker(context, appProvider.tolerance,
                  (final int newValue) {
                appProvider.tolerance = newValue;
              });
            },
          ),
          childRight: minimal
              ? null
              : TolerancePicker(
                  value: appProvider.tolerance,
                  onChanged: (final int value) {
                    appProvider.tolerance = value;
                  },
                ),
        ),
      );
    }

    // Top colors
    if (selectedTool.isSupported(ActionOptions.topColors)) {
      widgets.add(
        TopColors(
          colorUsages: layers.topColors,
          onRefresh: () {
            layers.evaluatTopColor();
            appProvider.update();
          },
          onColorPicked: (final Color color) {
            (appProvider.selectedAction == ActionType.rectangle ||
                    appProvider.selectedAction == ActionType.circle ||
                    appProvider.selectedAction == ActionType.fill)
                ? appProvider.fillColor = color
                : appProvider.brushColor = color;
          },
          minimal: minimal,
        ),
      );

      // Add a separator between each element
      if (!minimal) {
        final List<Widget> separatedWidgets = <Widget>[];
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
