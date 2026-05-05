import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/material_free.dart';
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
    final AppLocalizations l10n = context.l10n;

    return Column(
      spacing: AppSpacing.thin,
      children: <Widget>[
        // Font size
        ToolAttributeWidget(
          compact: minimal,
          name: l10n.fontSizeLabel,
          childLeft: AppButtonIcon(
            icon: AppIcon.formatSize,
            constraints: minimal ? const BoxConstraints() : null,
            padding: minimal ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.small),
            onPressed: () {
              showBrushSizePicker(
                context: context,
                title: l10n.fontSizeLabel,
                value: appProvider.textToolState.size,
                min: 1,
                max: AppLimits.brushSizeMax.toDouble(),
                onChanged: (final double newValue) {
                  appProvider.textToolState.size = newValue;
                  appProvider.update();
                },
              );
            },
          ),
          childRight: minimal
              ? null
              : BrushSizePicker(
                  title: l10n.fontSizeLabel,
                  value: appProvider.textToolState.size,
                  min: 1,
                  max: AppLimits.brushSizeMax.toDouble(),
                  onChanged: (final double value) {
                    appProvider.textToolState.size = value;
                    appProvider.update();
                  },
                ),
        ),

        ToolAttributeWidget(
          compact: minimal,
          name: l10n.contentAlignment,
          childLeft: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppButtonIcon(
                key: Keys.textEditorBoldButton,
                icon: AppIcon.formatBold,
                color: appProvider.textToolState.fontWeight == FontWeight.bold ? AppColors.blue : AppColors.grey,
                onPressed: () {
                  appProvider.textToolState.fontWeight = appProvider.textToolState.fontWeight == FontWeight.bold
                      ? FontWeight.normal
                      : FontWeight.bold;
                  appProvider.update();
                },
              ),
              AppButtonIcon(
                key: Keys.textEditorItalicButton,
                icon: AppIcon.formatItalic,
                color: appProvider.textToolState.fontStyle == FontStyle.italic ? AppColors.blue : AppColors.grey,
                onPressed: () {
                  appProvider.textToolState.fontStyle = appProvider.textToolState.fontStyle == FontStyle.italic
                      ? FontStyle.normal
                      : FontStyle.italic;
                  appProvider.update();
                },
              ),
            ],
          ),
          childRight: minimal
              ? null
              : AppDropdown<TextAlign>(
                  key: Keys.textEditorAlignmentDropdown,
                  value: appProvider.textToolState.textAlign,
                  items: <AppDropdownItem<TextAlign>>[
                    AppDropdownItem<TextAlign>(
                      value: TextAlign.left,
                      child: Text(l10n.textAlignLeft),
                    ),
                    AppDropdownItem<TextAlign>(
                      value: TextAlign.center,
                      child: Text(l10n.textAlignCenter),
                    ),
                    AppDropdownItem<TextAlign>(
                      value: TextAlign.right,
                      child: Text(l10n.textAlignRight),
                    ),
                  ],
                  onChanged: (final TextAlign? value) {
                    if (value == null) {
                      return;
                    }
                    appProvider.textToolState.textAlign = value;
                    appProvider.update();
                  },
                ),
        ),

        // Font color
        ToolAttributeWidget(
          compact: minimal,
          name: l10n.fontColor,
          childLeft: colorPreviewWithTransparentPaper(
            key: Keys.toolPanelFontColor,
            minimal: minimal,
            color: appProvider.textToolState.color,
            onPressed: () {
              showColorPicker(
                context: context,
                title: l10n.fontColor,
                color: appProvider.textToolState.color,
                onSelectedColor: (final Color color) {
                  appProvider.textToolState.color = color;
                  appProvider.update();
                },
              );
            },
          ),
          childRight: minimal
              ? null
              : ColorSelector(
                  color: appProvider.textToolState.color,
                  onColorChanged: (final Color color) {
                    appProvider.textToolState.color = color;
                    appProvider.update();
                  },
                ),
        ),
      ],
    );
  }
}
