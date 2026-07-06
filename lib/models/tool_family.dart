import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/user_action_drawing.dart';

/// Localized label for a gesture tool [action] shown in the tool rail.
///
/// Gesture tools and effects share one Brush section in the rail, so there is
/// no separate "brush mode" vs. "effect mode"; a tool is a gesture when it
/// carries an [ActionType] and an effect otherwise.
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
