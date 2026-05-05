import 'dart:ui' as ui;

import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_effects.dart';
import 'package:fpaint/models/app_icon_enum.dart';

/// Effects that can be applied to a selected region.
enum SelectionEffect {
  blur(AppIcon.effectBlur),
  brightness(AppIcon.effectBrightness),
  contrast(AppIcon.effectContrast),
  grayscale(AppIcon.effectGrayscale),
  hueSaturation(AppIcon.effectHueSaturation),
  noise(AppIcon.effectNoise),
  pixelate(AppIcon.effectPixelate),
  shadow(AppIcon.effectShadow),
  sharpen(AppIcon.effectSharpen),
  soften(AppIcon.effectSoften),
  vignette(AppIcon.effectVignette),
  ;

  const SelectionEffect(this.icon);

  /// The icon displayed for this effect.
  final AppIcon icon;

  /// Applies this effect to the given [image] and returns the processed result.
  ///
  /// [strength] controls how strongly the effect is applied (0.0 = none,
  /// 1.0 = full authored strength).
  Future<ui.Image> apply(
    final ui.Image image, {
    final double strength = AppEffects.defaultIntensity,
  }) async {
    final double appliedStrength = strength * AppEffects.intensityAppliedScale;

    switch (this) {
      case SelectionEffect.blur:
        return applyGaussianBlur(image, AppEffects.blurSigma, strength: appliedStrength);
      case SelectionEffect.brightness:
        return applyBrightness(image, strength: appliedStrength);
      case SelectionEffect.contrast:
        return applyContrast(image, strength: appliedStrength);
      case SelectionEffect.grayscale:
        return applyGrayscale(image, strength: appliedStrength);
      case SelectionEffect.hueSaturation:
        return applyHueSaturation(image, strength: appliedStrength);
      case SelectionEffect.noise:
        return applyNoise(image, strength: appliedStrength);
      case SelectionEffect.pixelate:
        return applyPixelate(image, strength: appliedStrength);
      case SelectionEffect.shadow:
        return applyShadow(image, strength: appliedStrength);
      case SelectionEffect.sharpen:
        return applySharpen(image, strength: appliedStrength);
      case SelectionEffect.soften:
        return applyGaussianBlur(image, AppEffects.softenSigma, strength: appliedStrength);
      case SelectionEffect.vignette:
        return applyVignette(image, strength: appliedStrength);
    }
  }
}
