import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/tool_item.dart';
import 'package:fpaint/widgets/color_picker.dart';
import 'package:fpaint/widgets/transparent_background.dart';
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
              buildTools(vertical: minimal),
              //
              // Divider
              //
              Divider(
                thickness: 8,
                height: 16,
                color: Colors.grey,
              ),

              Expanded(
                child: buildAttributes(
                  context: context,
                  appModel: appModel,
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
    required final AppModel appModel,
    required bool vertical,
  }) {
    List<Widget> widgets = [];

    // Stroke Weight
    if (currentShapeType.isSupported(ToolAttribute.brushSize)) {
      widgets.add(
        adjustmentWidget(
          name: 'Stroke Style',
          buttonIcon: Icons.line_weight,
          buttonIconColor: Colors.black,
          onButtonPressed: () {},
          child: vertical
              ? SizedBox()
              : Slider(
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
          child: vertical ? SizedBox() : brushSelection(appModel),
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
          transparentPaper: true,
          child: vertical
              ? SizedBox()
              : MyColorPicker(
                  color: appModel.colorForStroke,
                  onColorChanged: (Color color) =>
                      appModel.colorForStroke = color,
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
          transparentPaper: true,
          child: vertical
              ? SizedBox()
              : MyColorPicker(
                  color: appModel.colorForFill,
                  onColorChanged: (Color color) =>
                      appModel.colorForFill = color,
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

  Widget adjustmentWidget({
    required String name,
    required IconData buttonIcon,
    required Color buttonIconColor,
    required VoidCallback onButtonPressed,
    required Widget child,
    bool transparentPaper = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            margin: EdgeInsets.only(right: 8),
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                if (transparentPaper)
                  TransparentPaper(
                    patternSize: 4,
                  ),
                IconButton(
                  icon: Icon(buttonIcon),
                  onPressed: onButtonPressed,
                  color: buttonIconColor,
                  tooltip: name,
                ),
              ],
            ),
          ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }

  /// Displays a color picker dialog with the given title, initial color, and callback for the selected color.
  ///
  /// The color picker dialog is displayed using the [showDialog] function, and includes a [ColorPicker] widget
  /// that allows the user to select a color. The selected color is passed to the [onSelectedColor] callback.
  ///
  /// Parameters:
  /// - `context`: The [BuildContext] used to display the dialog.
  /// - `title`: The title of the color picker dialog.
  /// - `color`: The initial color to be displayed in the color picker.
  /// - `onSelectedColor`: A callback that is called when the user selects a color. The selected color is passed as an argument.
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
