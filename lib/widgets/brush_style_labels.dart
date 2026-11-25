import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/brush_style.dart';

/// Returns the localized display name for a [BrushStyle].
String brushStyleLabel(AppLocalizations l10n, BrushStyle style) {
  return switch (style) {
    BrushStyle.solid => l10n.brushStyleSolid,
    BrushStyle.dash => l10n.brushStyleDash,
    BrushStyle.dotted => l10n.brushStyleDotted,
    BrushStyle.dashDot => l10n.brushStyleDashDot,
    BrushStyle.slash => l10n.brushStyleSlash,
    BrushStyle.soft => l10n.brushStyleSoft,
    BrushStyle.grain => l10n.brushStyleGrain,
    BrushStyle.hatch => l10n.brushStyleHatch,
    BrushStyle.crossHatch => l10n.brushStyleCrossHatch,
    BrushStyle.hatchMarks => l10n.brushStyleHatchMarks,
  };
}

/// Returns the localized section heading for a [BrushStyleCategory].
String brushStyleCategoryLabel(AppLocalizations l10n, BrushStyleCategory category) {
  return switch (category) {
    BrushStyleCategory.lines => l10n.brushCategoryLines,
    BrushStyleCategory.sketching => l10n.brushCategorySketching,
    BrushStyleCategory.inking => l10n.brushCategoryInking,
  };
}
