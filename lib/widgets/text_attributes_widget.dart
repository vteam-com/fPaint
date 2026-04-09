import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/tool_attribute_widget.dart';

/// Renders font size and color controls for the text tool.
class TextAttributesWidget extends StatelessWidget {
  const TextAttributesWidget({
    super.key,
    required this.minimal,
  });

  final bool minimal;

  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: true);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Column(
      children: <Widget>[
        // Font size
        ToolAttributeWidget(
          minimal: minimal,
          name: l10n.fontSizeLabel,
          childLeft: IconButton(
            icon: const Icon(Icons.format_size),
            color: Colors.grey.shade500,
            constraints: minimal ? const BoxConstraints() : null,
            padding: minimal ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.sm),
            onPressed: () {
              showBrushSizePicker(
                context: context,
                title: l10n.fontSizeLabel,
                value: appProvider.brushSize,
                min: 1,
                max: AppLimits.brushSizeMax.toDouble(),
                onChanged: (final double newValue) {
                  appProvider.brushSize = newValue;
                },
              );
            },
          ),
          childRight: minimal
              ? null
              : BrushSizePicker(
                  title: l10n.fontSizeLabel,
                  value: appProvider.brushSize,
                  min: 1,
                  max: AppLimits.brushSizeMax.toDouble(),
                  onChanged: (final double value) {
                    appProvider.brushSize = value;
                  },
                ),
        ),
        separator(),
        // Font color
        ToolAttributeWidget(
          minimal: minimal,
          name: l10n.fontColor,
          childLeft: colorPreviewWithTransparentPaper(
            key: Keys.toolPanelFontColor,
            minimal: minimal,
            color: appProvider.brushColor,
            onPressed: () {
              showColorPicker(
                context: context,
                title: l10n.fontColor,
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

/// Builds a visual divider between text attribute controls.
Widget separator() {
  return const Divider(
    thickness: AppStroke.thin,
    height: AppLayout.separatorHeight,
    color: Colors.black,
  );
}
