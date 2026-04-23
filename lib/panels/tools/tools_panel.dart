import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/tools/tool_panel_picker.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/app_provider_tools.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/brush_style_picker.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/text_attributes_widget.dart';
import 'package:fpaint/widgets/tolerance_picker.dart';
import 'package:fpaint/widgets/tool_attribute_widget.dart';
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

  /// A boolean indicating whether the panel is in minimal mode.
  final bool minimal;
  @override
  Widget build(final BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Wrap(
            spacing: minimal ? AppSpacing.thin : AppSpacing.xs,
            runSpacing: minimal ? AppSpacing.thin : AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: getListOfTools(context),
          ),
          const Divider(
            color: Colors.black,
          ),
          Wrap(
            runSpacing: minimal ? AppSpacing.sm : AppSpacing.thin,
            alignment: WrapAlignment.center,
            children: getWidgetForSelectedTool(context: context),
          ),
        ],
      ),
    );
  }

  /// Adds a tool option for brush or fill color.
  void addToolOptionColor(
    final List<Widget> widgets,
    final AppProvider appProvider,
    final BuildContext context,
    final bool isBrush,
  ) {
    final String name = isBrush ? 'Brush Color' : 'Fill Color';
    final Key previewKey = isBrush ? Keys.toolPanelBrushColor1 : Keys.toolPanelFillColor;
    final Color color = isBrush ? appProvider.brushColor : appProvider.fillColor;
    _addToolOptionColor(
      widgets: widgets,
      context: context,
      name: name,
      previewKey: previewKey,
      color: color,
      onColorChanged: (final Color selectedColor) {
        if (isBrush) {
          appProvider.brushColor = selectedColor;
        } else {
          appProvider.fillColor = selectedColor;
        }
      },
      onPickFromCanvas: () {
        if (isBrush) {
          appProvider.eyeDropPositionForFill = null;
          appProvider.eyeDropPositionForBrush = appProvider.canvasCenter;
        } else {
          appProvider.eyeDropPositionForBrush = null;
          appProvider.eyeDropPositionForFill = appProvider.canvasCenter;
        }
        appProvider.update();
      },
    );
  }

  /// Adds a tool option for color tolerance.
  void addToolOptionTolerance(
    final List<Widget> widgets,
    final BuildContext context,
    final AppProvider appProvider,
  ) {
    final AppLocalizations l10n = context.l10n;

    widgets.add(
      ToolAttributeWidget(
        minimal: minimal,
        name: 'Color Tolerance',
        childLeft: IconButton(
          icon: const AppSvgIcon(icon: AppIcon.support),
          color: Colors.grey.shade500,
          onPressed: () {
            showTolerancePicker(context, appProvider.tolerance, (final int newValue) {
              appProvider.tolerance = newValue;
            });
          },
        ),
        childRight: minimal
            ? null
            : TolerancePicker(
                title: l10n.tolerance,
                value: appProvider.tolerance,
                onChanged: (final int value) {
                  appProvider.tolerance = value;
                },
              ),
      ),
    );
  }

  /// Adds a tool option for top colors.
  void addToolOptionTopColors(
    final List<Widget> widgets,
    final LayersProvider layers,
    final AppProvider appProvider,
    final bool minimal,
  ) {
    widgets.add(
      TopColors(
        colorUsages: layers.topColors,
        onRefresh: () {
          layers.evaluateTopColor();
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
  }

  /// Returns a list of widgets representing the available tools.
  List<Widget> getListOfTools(
    final BuildContext context,
  ) {
    final AppProvider appProvider = AppProvider.of(context);
    final AppLocalizations l10n = context.l10n;
    final ActionType selectedTool = appProvider.selectedAction;

    final List<Widget> tools = <Widget>[
      // Pencil
      ToolPanelPicker(
        minimal: minimal,
        name: 'Pencil',
        image: AppSvgIcon(
          icon: ActionType.pencil.icon,
          isSelected: selectedTool == ActionType.pencil,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.pencil;
        },
      ),

      // Brush
      ToolPanelPicker(
        minimal: minimal,
        name: 'Brush',
        image: AppSvgIcon(
          icon: ActionType.brush.icon,
          isSelected: selectedTool == ActionType.brush,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.brush;
        },
      ),

      // Line
      ToolPanelPicker(
        key: Keys.toolLine,
        minimal: minimal,
        name: 'Line',
        image: AppSvgIcon(
          icon: ActionType.line.icon,
          isSelected: selectedTool == ActionType.line,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.line;
        },
      ),

      // Rectangle
      ToolPanelPicker(
        key: Keys.toolRectangle,
        minimal: minimal,
        name: 'Rectangle',
        image: AppSvgIcon(
          icon: ActionType.rectangle.icon,
          isSelected: selectedTool == ActionType.rectangle,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.rectangle;
        },
      ),

      // Circle
      ToolPanelPicker(
        key: Keys.toolCircle,
        minimal: minimal,
        name: 'Circle',
        image: AppSvgIcon(
          icon: ActionType.circle.icon,
          isSelected: selectedTool == ActionType.circle,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.circle;
        },
      ),

      // Paint Bucket
      ToolPanelPicker(
        key: Keys.toolFill,
        minimal: minimal,
        name: 'Paint Bucket',
        image: AppSvgIcon(
          icon: ActionType.fill.icon,
          isSelected: selectedTool == ActionType.fill,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.fill;
        },
      ),

      ToolPanelPicker(
        minimal: minimal,
        name: 'Eraser',
        image: AppSvgIcon(
          icon: ActionType.eraser.icon,
          isSelected: selectedTool == ActionType.eraser,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.eraser;
        },
      ),

      // Text
      ToolPanelPicker(
        key: Keys.toolText,
        minimal: minimal,
        name: 'Text',
        image: AppSvgIcon(
          icon: ActionType.text.icon,
          isSelected: selectedTool == ActionType.text,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.text;
        },
      ),

      ToolPanelPicker(
        key: Keys.toolSelector,
        minimal: minimal,
        name: 'Selector',
        image: AppSvgIcon(
          icon: ActionType.selector.icon,
          isSelected: selectedTool == ActionType.selector,
        ),
        onPressed: () {
          appProvider.selectedAction = ActionType.selector;
        },
      ),

      // Paste from clipboard
      ToolPanelPicker(
        minimal: minimal,
        name: l10n.paste,
        image: AppSvgIcon(icon: AppIcon.paste, color: IconTheme.of(context).color),
        onPressed: () => appProvider.paste(),
      ),
    ];
    return tools;
  }

  /// Returns a list of widgets representing the attributes for the selected tool.
  List<Widget> getWidgetForSelectedTool({
    required final BuildContext context,
  }) {
    final List<Widget> widgets = <Widget>[];
    final AppProvider appProvider = AppProvider.of(context, listen: true);
    final AppLocalizations l10n = context.l10n;
    final LayersProvider layers = LayersProvider.of(context);
    final ActionType selectedTool = appProvider.selectedAction;

    switch (selectedTool) {
      case ActionType.fill:
        widgets.add(
          ToolAttributeWidget(
            minimal: minimal,
            name: 'Fill',
            childRight: Wrap(
              alignment: WrapAlignment.center,
              children: <Widget>[
                //
                // Selection using Rectangle
                //
                ToolPanelPicker(
                  key: Keys.toolFillModeSolid,
                  minimal: minimal,
                  name: 'Solid',
                  image: AppSvgIcon(icon: AppIcon.square, isSelected: appProvider.fillModel.mode == FillMode.solid),
                  onPressed: () {
                    appProvider.fillModel.mode = FillMode.solid;
                    appProvider.update();
                  },
                ),
                //
                // Linear Gradient
                //
                ToolPanelPicker(
                  key: Keys.toolFillModeLinear,
                  minimal: minimal,
                  name: 'Linear Gradient',
                  image: AppSvgIcon(
                    icon: AppIcon.fillLinear,
                    isSelected: appProvider.fillModel.mode == FillMode.linear,
                  ),
                  onPressed: () {
                    appProvider.fillModel.mode = FillMode.linear;
                    appProvider.update();
                    appProvider.updateGradientFill();
                  },
                ),
                //
                // Radial Gradient
                //
                ToolPanelPicker(
                  key: Keys.toolFillModeRadial,
                  minimal: minimal,
                  name: 'Radial Gradient',
                  image: AppSvgIcon(
                    icon: AppIcon.fillRadial,
                    isSelected: appProvider.fillModel.mode == FillMode.radial,
                  ),
                  onPressed: () {
                    appProvider.fillModel.mode = FillMode.radial;
                    appProvider.update();
                    appProvider.updateGradientFill();
                  },
                ),
              ],
            ),
          ),
        );
        addToolOptionColor(widgets, appProvider, context, false);
        addToolOptionTolerance(widgets, context, appProvider);
        addToolOptionTopColors(widgets, layers, appProvider, minimal);
        break;

      case ActionType.text:
        widgets.add(
          const TextAttributesWidget(
            minimal: false,
          ),
        );
        break;
      case ActionType.selector:
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
                  key: Keys.toolSelectorModeRectangle,
                  minimal: minimal,
                  name: 'Rectangle',
                  image: AppSvgIcon(
                    icon: AppIcon.selectorSquare,
                    isSelected: appProvider.selectorModel.mode == SelectorMode.rectangle,
                  ),
                  onPressed: () {
                    appProvider.selectorModel.mode = SelectorMode.rectangle;
                    appProvider.update();
                  },
                ),
                //
                // Selection using Circle
                //
                ToolPanelPicker(
                  key: Keys.toolSelectorModeCircle,
                  minimal: minimal,
                  name: 'Circle',
                  image: AppSvgIcon(
                    icon: AppIcon.selectorCircle,
                    isSelected: appProvider.selectorModel.mode == SelectorMode.circle,
                  ),
                  onPressed: () {
                    appProvider.selectorModel.mode = SelectorMode.circle;
                    appProvider.update();
                  },
                ),
                //
                // Selection using Drawing
                //
                ToolPanelPicker(
                  key: Keys.toolSelectorModeLasso,
                  minimal: minimal,
                  name: 'Lasso',
                  image: AppSvgIcon(
                    icon: AppIcon.lasso,
                    isSelected: appProvider.selectorModel.mode == SelectorMode.lasso,
                  ),
                  onPressed: () {
                    appProvider.selectorModel.mode = SelectorMode.lasso;
                    appProvider.update();
                  },
                ),
                //
                // Selection using magic wand
                //
                ToolPanelPicker(
                  key: Keys.toolSelectorModeWand,
                  minimal: minimal,
                  name: 'Magic',
                  image: AppSvgIcon(
                    icon: AppIcon.autoFixHigh,
                    isSelected: appProvider.selectorModel.mode == SelectorMode.wand,
                  ),
                  onPressed: () {
                    appProvider.selectorModel.mode = SelectorMode.wand;
                    appProvider.update();
                  },
                ),

                if (appProvider.selectorModel.isVisible) const Divider(),

                if (appProvider.selectorModel.isVisible)
                  ToolPanelPicker(
                    minimal: minimal,
                    name: 'Replace',
                    image: AppSvgIcon(
                      icon: AppIcon.selectorReplace,
                      isSelected: appProvider.selectorModel.math == SelectorMath.replace,
                    ),
                    onPressed: () {
                      appProvider.selectorModel.math = SelectorMath.replace;
                      appProvider.update();
                    },
                  ),

                if (appProvider.selectorModel.isVisible)
                  ToolPanelPicker(
                    minimal: minimal,
                    name: 'Add',
                    image: AppSvgIcon(
                      icon: AppIcon.selectorAdd,
                      isSelected: appProvider.selectorModel.math == SelectorMath.add,
                    ),
                    onPressed: () {
                      appProvider.selectorModel.math = SelectorMath.add;
                      appProvider.update();
                    },
                  ),

                if (appProvider.selectorModel.isVisible)
                  ToolPanelPicker(
                    minimal: minimal,
                    name: 'Remove',
                    image: AppSvgIcon(
                      icon: AppIcon.selectorRemove,
                      isSelected: appProvider.selectorModel.math == SelectorMath.remove,
                    ),
                    onPressed: () {
                      appProvider.selectorModel.math = SelectorMath.remove;
                      appProvider.update();
                    },
                  ),

                if (appProvider.selectorModel.isVisible) const Divider(),

                if (appProvider.selectorModel.isVisible)
                  ToolPanelPicker(
                    minimal: minimal,
                    name: 'Invert',
                    image: const AppSvgIcon(
                      icon: AppIcon.selectorInvert,
                      isSelected: false,
                    ),
                    onPressed: () {
                      appProvider.selectorModel.invert(
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

                if (appProvider.selectorModel.isVisible)
                  ToolPanelPicker(
                    minimal: minimal,
                    name: 'Crop',
                    image: const AppSvgIcon(icon: AppIcon.canvasCrop, isSelected: false),
                    onPressed: () {
                      final ShellProvider shellProvider = ShellProvider.of(context);
                      shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
                      shellProvider.update();

                      appProvider.crop();
                      appProvider.update();
                    },
                  ),

                if (appProvider.selectorModel.isVisible) const Divider(),

                for (final SelectionEffect effect in SelectionEffect.values)
                  ToolPanelPicker(
                    minimal: minimal,
                    name: effectLabel(l10n, effect),
                    image: AppSvgIcon(icon: effect.icon, isSelected: false),
                    onPressed: () => appProvider.applyEffect(effect),
                  ),

                if (appProvider.selectorModel.isVisible) const Divider(),

                if (appProvider.selectorModel.isVisible)
                  ToolPanelPicker(
                    key: Keys.toolSelectorCancel,
                    minimal: minimal,
                    name: 'Cancel',
                    image: const AppSvgIcon(
                      icon: AppIcon.close,
                      isSelected: false,
                    ),
                    onPressed: () {
                      appProvider.selectorModel.clear();
                      appProvider.update();
                    },
                  ),
              ],
            ),
          ),
        );

        if (appProvider.selectorModel.mode == SelectorMode.wand) {
          addToolOptionTolerance(widgets, context, appProvider);
        }
        break;

      default:
        final String title = appProvider.selectedAction == ActionType.pencil ? 'Pencil Size' : 'Brush Size';
        final double min = appProvider.selectedAction == ActionType.pencil ? 1 : AppInteraction.minCanvasScale;
        final double max = AppLimits.percentMax.toDouble();

        // Brush Size
        if (selectedTool.isSupported(ActionOptions.brushSize)) {
          widgets.add(
            ToolAttributeWidget(
              key: const Key('tool_brush_size_tool'),
              minimal: minimal,
              name: title,
              childLeft: IconButton(
                key: const Key('tool_brush_size_button'),
                icon: const AppSvgIcon(icon: AppIcon.lineWeight),
                color: Colors.grey.shade500,
                constraints: minimal ? const BoxConstraints() : null,
                padding: minimal ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.sm),
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
                      key: const Key('tool_brush_size_slider'),
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
                icon: const AppSvgIcon(icon: AppIcon.lineStyle),
                color: Colors.grey.shade500,
                constraints: minimal ? const BoxConstraints() : null,
                padding: minimal ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.sm),
                onPressed: () {
                  showBrushStylePicker(
                    context,
                    appProvider.brushStyle,
                    (final BrushStyle selectedBrushStyle) => appProvider.brushStyle = selectedBrushStyle,
                  );
                },
              ),
              childRight: minimal
                  ? null
                  : brushStyleDropDown(
                      appProvider.brushStyle,
                      (final BrushStyle selectedBrushStyle) => appProvider.brushStyle = selectedBrushStyle,
                    ),
            ),
          );
        }

        // Brush color
        if (selectedTool.isSupported(ActionOptions.brushColor)) {
          addToolOptionColor(widgets, appProvider, context, true);
        }

        // Fill Color
        if (selectedTool.isSupported(ActionOptions.colorFill)) {
          addToolOptionColor(widgets, appProvider, context, false);
        }

        // Color Tolerance used by Fill and Magic wand
        if (selectedTool.isSupported(ActionOptions.tolerance)) {
          addToolOptionTolerance(widgets, context, appProvider);
        }

        // Top colors
        if (selectedTool.isSupported(ActionOptions.topColors)) {
          addToolOptionTopColors(widgets, layers, appProvider, minimal);
        }
    }
    // Add a separator between each element
    if (!minimal) {
      final List<Widget> separatedWidgets = <Widget>[];
      for (int i = 0; i < widgets.length; i++) {
        separatedWidgets.add(widgets[i]);
        separatedWidgets.add(separator());
      }
      return separatedWidgets;
    }

    return widgets;
  }

  /// Adds a color-related tool option row with preview, picker, and selector.
  void _addToolOptionColor({
    required final List<Widget> widgets,
    required final BuildContext context,
    required final String name,
    required final Key previewKey,
    required final Color color,
    required final ValueChanged<Color> onColorChanged,
    required final VoidCallback onPickFromCanvas,
  }) {
    widgets.add(
      ToolAttributeWidget(
        minimal: minimal,
        name: name,
        childLeft: Column(
          children: <Widget>[
            colorPreviewWithTransparentPaper(
              key: previewKey,
              minimal: minimal,
              color: color,
              onPressed: () {
                showColorPicker(
                  context: context,
                  title: name,
                  color: color,
                  onSelectedColor: onColorChanged,
                );
              },
            ),
            IconButton(
              icon: const AppSvgIcon(icon: AppIcon.colorize),
              onPressed: onPickFromCanvas,
            ),
          ],
        ),
        childRight: minimal
            ? null
            : ColorSelector(
                color: color,
                onColorChanged: onColorChanged,
              ),
      ),
    );
  }
}

/// Returns a widget that displays a separator.
Widget separator() {
  return const Divider(
    thickness: AppStroke.thin,
    height: AppLayout.separatorHeight,
    color: Colors.black,
  );
}
