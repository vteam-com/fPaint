import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/user_action_drawing.dart';

/// High-level grouping of tools by how they change pixels.
///
/// The rail presents the two families so the user never switches between a
/// "brush mode" and an "effect mode": everything applied by gesture (including
/// smudge) is a brush under [draw], region filters live under [adjust], and
/// selection is an orthogonal modifier.
enum ToolFamily {
  /// Applied by gesture — pencil, brush, smudge, shapes, fill, eraser, text.
  draw,

  /// Region filter applied to the layer or selection — the effects.
  adjust,
}

/// Localized section header for a tool [family].
String toolFamilyLabel(final AppLocalizations l10n, final ToolFamily family) {
  switch (family) {
    case ToolFamily.draw:
      return l10n.toolFamilyDraw;
    case ToolFamily.adjust:
      return l10n.toolFamilyAdjust;
  }
}

/// Localized label for a gesture tool [action] shown in the tool rail.
String toolLabel(final AppLocalizations l10n, final ActionType action) {
  switch (action) {
    case ActionType.pencil:
      return l10n.toolPencil;
    case ActionType.brush:
      return l10n.toolBrush;
    case ActionType.smudge:
      return l10n.toolSmudge;
    case ActionType.blurBrush:
      return l10n.toolBlurBrush;
    case ActionType.line:
      return l10n.toolLine;
    case ActionType.rectangle:
      return l10n.toolRectangle;
    case ActionType.circle:
      return l10n.toolCircle;
    case ActionType.fill:
      return l10n.toolPaintBucket;
    case ActionType.eraser:
      return l10n.toolEraser;
    case ActionType.text:
      return l10n.toolText;
    // Actions that never appear in the tool rail.
    case ActionType.region:
    case ActionType.image:
    case ActionType.cut:
    case ActionType.selector:
      return action.name;
  }
}
