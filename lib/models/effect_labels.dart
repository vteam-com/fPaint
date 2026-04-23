import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/selection_effect.dart';

/// Returns the localized label for a [SelectionEffect].
String effectLabel(
  final AppLocalizations l10n,
  final SelectionEffect effect,
) {
  switch (effect) {
    case SelectionEffect.blur:
      return l10n.effectBlur;
    case SelectionEffect.sharpen:
      return l10n.effectSharpen;
    case SelectionEffect.pixelate:
      return l10n.effectPixelate;
    case SelectionEffect.grayscale:
      return l10n.effectGrayscale;
    case SelectionEffect.noise:
      return l10n.effectNoise;
    case SelectionEffect.soften:
      return l10n.effectSoften;
    case SelectionEffect.vignette:
      return l10n.effectVignette;
  }
}
