import 'dart:ui' as ui;

import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_effects.dart';
import 'package:fpaint/models/app_icon_enum.dart';

/// Effects that can be applied to a selected region.
enum SelectionEffect {
  blur(AppIcon.effectBlur),
  sharpen(AppIcon.effectSharpen),
  pixelate(AppIcon.effectPixelate),
  grayscale(AppIcon.effectGrayscale),
  noise(AppIcon.effectNoise),
  soften(AppIcon.effectSoften),
  vignette(AppIcon.effectVignette),
  ;

  const SelectionEffect(this.icon);

  /// The icon displayed for this effect.
  final AppIcon icon;

  /// Applies this effect to the given [image] and returns the processed result.
  Future<ui.Image> apply(final ui.Image image) async {
    switch (this) {
      case SelectionEffect.blur:
        return applyGaussianBlur(image, AppEffects.blurSigma);
      case SelectionEffect.sharpen:
        return applySharpen(image);
      case SelectionEffect.pixelate:
        return applyPixelate(image);
      case SelectionEffect.grayscale:
        return applyGrayscale(image);
      case SelectionEffect.noise:
        return applyNoise(image);
      case SelectionEffect.soften:
        return applyGaussianBlur(image, AppEffects.softenSigma);
      case SelectionEffect.vignette:
        return applyVignette(image);
    }
  }
}
