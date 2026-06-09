import 'dart:ui' as ui;

import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_effects.dart';
import 'package:fpaint/models/app_icon_enum.dart';

typedef _SelectionEffectApply =
    Future<ui.Image> Function(
      ui.Image image,
      double strength,
      double size,
    );

typedef _SelectionEffectSizeValueResolver = int Function(double size);

/// Static metadata and apply callback for a selection effect.
class _SelectionEffectConfig {
  const _SelectionEffectConfig({
    required this.icon,
    required this.apply,
    this.supportsSizeControl = false,
    this.defaultSize = AppEffects.minSize,
    this.sizeValueResolver = _defaultSelectionEffectSizeValue,
  });

  final AppIcon icon;
  final bool supportsSizeControl;
  final double defaultSize;
  final _SelectionEffectSizeValueResolver sizeValueResolver;
  final _SelectionEffectApply apply;
}

/// Effects that can be applied to a selected region.
enum SelectionEffect {
  blur(
    _SelectionEffectConfig(
      icon: AppIcon.effectBlur,
      apply: _applyBlurEffect,
    ),
  ),
  brightness(
    _SelectionEffectConfig(
      icon: AppIcon.effectBrightness,
      apply: _applyBrightnessEffect,
    ),
  ),
  contrast(
    _SelectionEffectConfig(
      icon: AppIcon.effectContrast,
      apply: _applyContrastEffect,
    ),
  ),
  grayscale(
    _SelectionEffectConfig(
      icon: AppIcon.effectGrayscale,
      apply: _applyGrayscaleEffect,
    ),
  ),
  hueSaturation(
    _SelectionEffectConfig(
      icon: AppIcon.effectHueSaturation,
      apply: _applyHueSaturationEffect,
    ),
  ),
  noise(
    _SelectionEffectConfig(
      icon: AppIcon.effectNoise,
      apply: _applyNoiseEffect,
      supportsSizeControl: true,
      defaultSize: AppEffects.noiseDefaultSize,
      sizeValueResolver: _noiseSelectionEffectSizeValue,
    ),
  ),
  pixelate(
    _SelectionEffectConfig(
      icon: AppIcon.effectPixelate,
      apply: _applyPixelateEffect,
      supportsSizeControl: true,
      defaultSize: AppEffects.pixelateDefaultSize,
      sizeValueResolver: _pixelateSelectionEffectSizeValue,
    ),
  ),
  shadow(
    _SelectionEffectConfig(
      icon: AppIcon.effectShadow,
      apply: _applyShadowEffect,
    ),
  ),
  sharpen(
    _SelectionEffectConfig(
      icon: AppIcon.effectSharpen,
      apply: _applySharpenEffect,
    ),
  ),
  soften(
    _SelectionEffectConfig(
      icon: AppIcon.effectSoften,
      apply: _applySoftenEffect,
    ),
  ),
  vignette(
    _SelectionEffectConfig(
      icon: AppIcon.effectVignette,
      apply: _applyVignetteEffect,
    ),
  ),
  ;

  const SelectionEffect(this._config);

  final _SelectionEffectConfig _config;

  /// The icon displayed for this effect.
  AppIcon get icon => _config.icon;

  /// Whether this effect exposes a size control in the UI.
  bool get supportsSizeControl => _config.supportsSizeControl;

  /// Default UI size value for this effect.
  double get defaultSize => _config.defaultSize;

  /// Returns the integer size value shown for effects that support size control.
  int sizeValue(final double size) {
    return _config.sizeValueResolver(size);
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
  }) {
    final double appliedStrength = strength * AppEffects.intensityAppliedScale;
    final double appliedSize = size ?? defaultSize;
    return _config.apply(image, appliedStrength, appliedSize);
  }
}

int _defaultSelectionEffectSizeValue(final double _) {
  return AppEffects.noiseMinCellSize;
}

int _noiseSelectionEffectSizeValue(final double size) {
  final double clampedSize = size.clamp(AppEffects.minSize, AppEffects.maxSize);
  return AppEffects.noiseMinCellSize +
      (((AppEffects.noiseMaxCellSize - AppEffects.noiseMinCellSize).toDouble()) * clampedSize).round();
}

int _pixelateSelectionEffectSizeValue(final double size) {
  final double clampedSize = size.clamp(AppEffects.minSize, AppEffects.maxSize);
  return AppEffects.pixelateMinBlockSize +
      (((AppEffects.pixelateMaxBlockSize - AppEffects.pixelateMinBlockSize).toDouble()) * clampedSize).round();
}

Future<ui.Image> _applyBlurEffect(
  final ui.Image image,
  final double strength,
  final double _,
) {
  return applyGaussianBlur(image, AppEffects.blurSigma, strength: strength);
}

Future<ui.Image> _applyBrightnessEffect(
  final ui.Image image,
  final double strength,
  final double _,
) {
  return applyBrightness(image, strength: strength);
}

Future<ui.Image> _applyContrastEffect(
  final ui.Image image,
  final double strength,
  final double _,
) {
  return applyContrast(image, strength: strength);
}

Future<ui.Image> _applyGrayscaleEffect(
  final ui.Image image,
  final double strength,
  final double _,
) {
  return applyGrayscale(image, strength: strength);
}

Future<ui.Image> _applyHueSaturationEffect(
  final ui.Image image,
  final double strength,
  final double _,
) {
  return applyHueSaturation(image, strength: strength);
}

Future<ui.Image> _applyNoiseEffect(
  final ui.Image image,
  final double strength,
  final double size,
) {
  return applyNoise(image, strength: strength, size: size);
}

Future<ui.Image> _applyPixelateEffect(
  final ui.Image image,
  final double strength,
  final double size,
) {
  return applyPixelate(image, strength: strength, size: size);
}

Future<ui.Image> _applyShadowEffect(
  final ui.Image image,
  final double strength,
  final double _,
) {
  return applyShadow(image, strength: strength);
}

Future<ui.Image> _applySharpenEffect(
  final ui.Image image,
  final double strength,
  final double _,
) {
  return applySharpen(image, strength: strength);
}

Future<ui.Image> _applySoftenEffect(
  final ui.Image image,
  final double strength,
  final double _,
) {
  return applyGaussianBlur(image, AppEffects.softenSigma, strength: strength);
}

Future<ui.Image> _applyVignetteEffect(
  final ui.Image image,
  final double strength,
  final double _,
) {
  return applyVignette(image, strength: strength);
}
