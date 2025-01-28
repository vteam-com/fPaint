import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/tools/tool_attributes_widget.dart';
import 'package:fpaint/panels/tools/tool_selector.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/color_picker.dart';
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
        return Container(
          constraints: const BoxConstraints(
            maxHeight: 400,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              buildTools(vertical: minimal),
              //
              // Divider
              //
              const Divider(
                thickness: 6,
                height: 10,
              ),

              Expanded(
                child: buildAttributes(
                  context: context,
                  vertical: minimal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the tools panel, which displays a row of tool items that the user can
  /// select to perform various actions in the application.
  ///
  /// The `buildTools` method returns a `Row` widget that contains a list of
  /// `ToolItem` widgets, each representing a different tool that the user can
  /// select. The selected tool is determined by the `currentShapeType` property,
  /// and the `onShapeSelected` callback is called when the user selects a tool.
  Widget buildTools({required bool vertical}) {
    final List<Widget> tools = [
      // Pencil
      ToolSelector(
        name: 'Draw',
        icon: Icons.brush,
        isSelected: currentShapeType == Tools.draw,
        onPressed: () => onShapeSelected(Tools.draw),
      ),

      // Line
      ToolSelector(
        name: 'Line',
        icon: Icons.line_axis,
        isSelected: currentShapeType == Tools.line,
        onPressed: () => onShapeSelected(Tools.line),
      ),

      // Rectangle
      ToolSelector(
        name: 'Rectangle',
        icon: Icons.crop_square,
        isSelected: currentShapeType == Tools.rectangle,
        onPressed: () => onShapeSelected(Tools.rectangle),
      ),

      // Circle
      ToolSelector(
        name: 'Circle',
        icon: Icons.circle_outlined,
        isSelected: currentShapeType == Tools.circle,
        onPressed: () => onShapeSelected(Tools.circle),
      ),

      ToolSelector(
        name: 'Eraser',
        icon: Icons.cleaning_services,
        isSelected: currentShapeType == Tools.eraser,
        onPressed: () => onShapeSelected(Tools.eraser),
      ),
    ];

    if (vertical) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tools,
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tools,
      );
    }
  }

  /// The `buildAttributes` method creates a list of widgets that represent various
  /// tool attributes, such as stroke weight, brush style, stroke color, and fill
  /// color. The method checks if the current shape type supports each attribute,
  /// and if so, it adds a corresponding widget to the list. The list of widgets
  /// is then returned as a `SizedBox` with a `ListView.separated` to display the
  /// attributes.
  Widget buildAttributes({
    required final BuildContext context,
    required bool vertical,
  }) {
    List<Widget> widgets = [];
    final appModel = AppModel.get(context, listen: true);

    // Stroke Weight
    if (currentShapeType.isSupported(ToolAttribute.brushSize)) {
      widgets.add(
        ToolAttributeWidget(
          name: 'Brush Style',
          buttonIcon: Icons.line_weight,
          buttonIconColor: Colors.grey.shade500,
          onButtonPressed: () {
            showBrushSizePicker(context, appModel.brusSize,
                (final double newValue) {
              appModel.brusSize = newValue;
            });
          },
          child: vertical
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
          child: vertical ? null : brushStyleSelection(appModel),
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
          child: vertical
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
          child: vertical
              ? null
              : MyColorPicker(
                  color: appModel.fillColor,
                  onColorChanged: (Color color) => appModel.fillColor = color,
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
}
