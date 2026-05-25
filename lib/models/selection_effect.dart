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

  /// Whether this effect exposes a size control in the UI.
  bool get supportsSizeControl {
    return this == SelectionEffect.noise || this == SelectionEffect.pixelate;
  }

  /// Default UI size value for this effect.
  double get defaultSize {
    switch (this) {
      case SelectionEffect.noise:
        return AppEffects.noiseDefaultSize;
      case SelectionEffect.pixelate:
        return AppEffects.pixelateDefaultSize;
      case SelectionEffect.blur:
      case SelectionEffect.brightness:
      case SelectionEffect.contrast:
      case SelectionEffect.grayscale:
      case SelectionEffect.hueSaturation:
      case SelectionEffect.shadow:
      case SelectionEffect.sharpen:
      case SelectionEffect.soften:
      case SelectionEffect.vignette:
        return AppEffects.minSize;
    }
  }

  /// Returns the integer size value shown for effects that support size control.
  int sizeValue(final double size) {
    final double clampedSize = size.clamp(AppEffects.minSize, AppEffects.maxSize);
    switch (this) {
      case SelectionEffect.noise:
        return AppEffects.noiseMinCellSize +
            (((AppEffects.noiseMaxCellSize - AppEffects.noiseMinCellSize).toDouble()) * clampedSize).round();
      case SelectionEffect.pixelate:
        return AppEffects.pixelateMinBlockSize +
            (((AppEffects.pixelateMaxBlockSize - AppEffects.pixelateMinBlockSize).toDouble()) * clampedSize).round();
      case SelectionEffect.blur:
      case SelectionEffect.brightness:
      case SelectionEffect.contrast:
      case SelectionEffect.grayscale:
      case SelectionEffect.hueSaturation:
      case SelectionEffect.shadow:
      case SelectionEffect.sharpen:
      case SelectionEffect.soften:
      case SelectionEffect.vignette:
        return AppEffects.noiseMinCellSize;
    }
  }

  /// Applies this effect to the given [image] and returns the processed result.
  ///
  /// [strength] controls how strongly the effect is applied (0.0 = none,
  /// 1.0 = full authored strength).
  ///
  /// [size] controls effect-specific block or grain sizing where supported.
  Future<ui.Image> apply(
    final ui.Image image, {
    final double strength = AppEffects.defaultIntensity,
    final double? size,
  }) async {
    final double appliedStrength = strength * AppEffects.intensityAppliedScale;
    final double appliedSize = size ?? defaultSize;

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
        return applyNoise(image, strength: appliedStrength, size: appliedSize);
      case SelectionEffect.pixelate:
        return applyPixelate(image, strength: appliedStrength, size: appliedSize);
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
