import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/widgets/brush_stroke_preview.dart';
import 'package:fpaint/widgets/brush_style_labels.dart';
import 'package:fpaint/widgets/material_free.dart';

/// The grid of brush tiles, one section per [BrushStyleCategory].
class BrushLibrary extends StatelessWidget {
  /// Creates a [BrushLibrary].
  const BrushLibrary({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Called with the tapped style.
  final ValueChanged<BrushStyle> onChanged;

  /// The currently selected style, drawn highlighted.
  final BrushStyle value;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final BrushStyleCategory category in BrushStyleCategory.values) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.big, bottom: AppSpacing.small),
            child: AppText(
              brushStyleCategoryLabel(l10n, category),
              variant: AppTextVariant.label,
              color: AppColors.textSecondary,
            ),
          ),
          Wrap(
            spacing: AppSpacing.medium,
            runSpacing: AppSpacing.medium,
            children: <Widget>[
              for (final BrushStyle style in category.styles)
                _BrushTile(
                  key: ValueKey<BrushStyle>(style),
                  style: style,
                  label: brushStyleLabel(l10n, style),
                  isSelected: style == value,
                  onTap: () => onChanged(style),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One library tile: a live stroke preview above the style name.
class _BrushTile extends StatelessWidget {
  const _BrushTile({
    super.key,
    required this.style,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final String label;
  final VoidCallback onTap;
  final BrushStyle style;

  @override
  Widget build(BuildContext context) {
    return BrushPreviewTapTarget(
      label: label,
      isSelected: isSelected,
      onTap: onTap,
      child: Container(
        width: AppBrushLibrary.tileWidth,
        padding: const EdgeInsets.all(AppSpacing.small),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.hover : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isSelected ? AppColors.selected : AppColors.divider,
            width: isSelected ? AppBrushLibrary.selectedBorderWidth : AppBrushLibrary.borderWidth,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: AppBrushLibrary.tilePreviewHeight,
              width: double.infinity,
              child: BrushStrokePreview(style: style, brushSize: AppBrushLibrary.previewBrushSize),
            ),
            AppText(
              label,
              variant: isSelected ? AppTextVariant.bodyBold : AppTextVariant.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
