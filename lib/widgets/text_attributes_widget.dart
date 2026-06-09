import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/text_tool_state.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/text_formatting_controls.dart';
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
    final AppProvider appProvider = AppProvider.of(context);
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
                titleIcon: const AppSvgIcon(icon: AppIcon.formatSize),
                value: appProvider.textToolState.size,
                min: 1,
                max: AppLimits.brushSizeMax.toDouble(),
                onChanged: (final double newValue) {
                  appProvider.setTextToolSize(newValue);
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
                    appProvider.setTextToolSize(value);
                  },
                ),
        ),

        ToolAttributeWidget(
          compact: minimal,
          name: l10n.contentAlignment,
          childLeft: TextStyleToggleButtons(
            value: appProvider.textToolState,
            onChanged: appProvider.applyTextToolState,
          ),
          childRight: minimal
              ? null
              : TextAlignmentDropdown(
                  l10n: l10n,
                  value: appProvider.textToolState.textAlign,
                  onChanged: (final TextAlign value) {
                    final TextToolState nextValue = appProvider.textToolState.copy();
                    nextValue.textAlign = value;
                    appProvider.applyTextToolState(nextValue);
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
                  appProvider.setTextToolColor(color);
                },
              );
            },
          ),
          childRight: minimal
              ? null
              : ColorSelector(
                  color: appProvider.textToolState.color,
                  onColorChanged: (final Color color) {
                    appProvider.setTextToolColor(color);
                  },
                ),
        ),
      ],
    );
  }
}
