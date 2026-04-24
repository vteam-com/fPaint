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
  ///
  /// [strength] controls how strongly the effect is applied (0.0 = none,
  /// 1.0 = full authored strength).
  Future<ui.Image> apply(
    final ui.Image image, {
    final double strength = AppEffects.defaultIntensity,
  }) async {
    switch (this) {
      case SelectionEffect.blur:
        return applyGaussianBlur(image, AppEffects.blurSigma, strength: strength);
      case SelectionEffect.sharpen:
        return applySharpen(image, strength: strength);
      case SelectionEffect.pixelate:
        return applyPixelate(image, strength: strength);
      case SelectionEffect.grayscale:
        return applyGrayscale(image, strength: strength);
      case SelectionEffect.noise:
        return applyNoise(image, strength: strength);
      case SelectionEffect.soften:
        return applyGaussianBlur(image, AppEffects.softenSigma, strength: strength);
      case SelectionEffect.vignette:
        return applyVignette(image, strength: strength);
    }
  }
}
