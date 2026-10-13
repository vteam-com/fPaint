import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/selector_model.dart';

/// Icon and localized label for each [SelectorMode], shared by every surface
/// that offers the selection modes (the selection sub-toolbar, the quick menu).
extension SelectorModeDisplay on SelectorMode {
  /// The icon shown on a button that picks this mode.
  AppIcon get icon => switch (this) {
    SelectorMode.rectangle => AppIcon.selectorSquare,
    SelectorMode.circle => AppIcon.selectorCircle,
    SelectorMode.line => AppIcon.selectorPolygon,
    SelectorMode.lasso => AppIcon.selectorLasso,
    SelectorMode.brush => AppIcon.selectorBrush,
    SelectorMode.wand => AppIcon.selectorWand,
  };

  /// The localized label / tooltip for this mode.
  String label(AppLocalizations l10n) => switch (this) {
    SelectorMode.rectangle => l10n.toolRectangle,
    SelectorMode.circle => l10n.toolCircle,
    SelectorMode.line => l10n.toolLine,
    SelectorMode.lasso => l10n.toolLasso,
    SelectorMode.brush => l10n.toolSelectionBrush,
    SelectorMode.wand => l10n.toolMagic,
  };
}
