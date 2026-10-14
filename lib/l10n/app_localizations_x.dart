import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/app_math.dart';
import 'package:fpaint/l10n/app_localizations.dart';

/// Convenience accessor so widgets can read localizations via `context.l10n`.
extension AppLocalizationsBuildContextX on BuildContext {
  /// Returns the [AppLocalizations] instance for this [BuildContext].
  AppLocalizations get l10n {
    final AppLocalizations? localizations = AppLocalizations.of(this);
    assert(localizations != null, 'AppLocalizations not found in context.');
    return localizations!;
  }
}

/// Formats a unit [fraction] (0..1, or -1..1 for bipolar strengths) as a
/// localized, rounded percentage, e.g. `0.5` → "50%".
String formatFractionPercent(AppLocalizations l10n, double fraction) {
  return l10n.percentageValue((fraction * AppMath.percentScale).round());
}
