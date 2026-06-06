import 'package:flutter/widgets.dart';
import 'package:fpaint/l10n/app_localizations.dart';

export 'package:fpaint/l10n/app_localizations.dart';

/// Convenience accessor so widgets can read localizations via `context.l10n`.
extension AppLocalizationsBuildContextX on BuildContext {
  /// Returns the [AppLocalizations] instance for this [BuildContext].
  AppLocalizations get l10n {
    final AppLocalizations? localizations = AppLocalizations.of(this);
    assert(localizations != null, 'AppLocalizations not found in context.');
    return localizations!;
  }
}
