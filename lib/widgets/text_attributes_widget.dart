import 'package:flutter/material.dart';
import 'package:fpaint/models/constants.dart';
import 'package:fpaint/panels/tools/tool_attributes_widget.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';

class TextAttributesWidget extends StatelessWidget {
  const TextAttributesWidget({
    super.key,
    required this.minimal,
  });

  final bool minimal;

  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: true);

    return Column(
      children: <Widget>[
        // Font size
        ToolAttributeWidget(
          minimal: minimal,
          name: 'Font Size',
          childLeft: IconButton(
            icon: const Icon(Icons.format_size),
            color: Colors.grey.shade500,
            constraints: minimal ? const BoxConstraints() : null,
            padding: minimal ? EdgeInsets.zero : const EdgeInsets.all(8),
            onPressed: () {
              showBrushSizePicker(
                context: context,
                title: 'Font Size',
                value: appProvider.brushSize,
                min: 1,
                max: 200,
                onChanged: (final double newValue) {
                  appProvider.brushSize = newValue;
                },
              );
            },
          ),
          childRight: minimal
              ? null
              : BrushSizePicker(
                  title: 'Font Size',
                  value: appProvider.brushSize,
                  min: 1,
                  max: 200,
                  onChanged: (final double value) {
                    appProvider.brushSize = value;
                  },
                ),
        ),
        separator(),
        // Font color
        ToolAttributeWidget(
          minimal: minimal,
          name: 'Font Color',
          childLeft: colorPreviewWithTransparentPaper(
            key: Keys.toolPanelFontColor,
            minimal: minimal,
            color: appProvider.brushColor,
            onPressed: () {
              showColorPicker(
                context: context,
                title: 'Font Color',
                color: appProvider.brushColor,
                onSelectedColor: (final Color color) => appProvider.brushColor = color,
              );
            },
          ),
          childRight: minimal
              ? null
              : ColorSelector(
                  color: appProvider.brushColor,
                  onColorChanged: (final Color color) => appProvider.brushColor = color,
                ),
        ),
      ],
    );
  }
}

Widget separator() {
  return const Divider(
    thickness: 1,
    height: 15,
    color: Colors.black,
  );
}
