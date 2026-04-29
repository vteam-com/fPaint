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
    case SelectionEffect.brightness:
      return l10n.effectBrightness;
    case SelectionEffect.contrast:
      return l10n.effectContrast;
    case SelectionEffect.grayscale:
      return l10n.effectGrayscale;
    case SelectionEffect.hueSaturation:
      return l10n.effectHueSaturation;
    case SelectionEffect.noise:
      return l10n.effectNoise;
    case SelectionEffect.pixelate:
      return l10n.effectPixelate;
    case SelectionEffect.shadow:
      return l10n.effectShadow;
    case SelectionEffect.sharpen:
      return l10n.effectSharpen;
    case SelectionEffect.soften:
      return l10n.effectSoften;
    case SelectionEffect.vignette:
      return l10n.effectVignette;
  }
}
