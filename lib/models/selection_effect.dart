import 'dart:ui' as ui;

import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_effects.dart';
import 'package:fpaint/models/app_icon_enum.dart';

typedef _SelectionEffectApply = Future<ui.Image> Function(
  ui.Image image,
  double strength,
  double size,
  double pixelScale,
);

typedef _SelectionEffectSizeValueResolver = int Function(double size);

/// Static metadata and apply callback for a selection effect.
class _SelectionEffectConfig {
  const _SelectionEffectConfig({
    required this.icon,
    required this.apply,
    this.supportsSizeControl = false,
    this.bipolar = false,
    this.defaultSize = AppEffects.minSize,
    this.sizeValueResolver = _defaultSelectionEffectSizeValue,
  });

  final AppIcon icon;
  final bool supportsSizeControl;
  final bool bipolar;
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
  sharpness(
    _SelectionEffectConfig(
      icon: AppIcon.effectSharpen,
      apply: _applySharpnessEffect,
      bipolar: true,
    ),
  ),
  brightness(
    _SelectionEffectConfig(
      icon: AppIcon.effectBrightness,
      apply: _applyBrightnessEffect,
      bipolar: true,
    ),
  ),
  contrast(
    _SelectionEffectConfig(
      icon: AppIcon.effectContrast,
      apply: _applyContrastEffect,
      bipolar: true,
    ),
  ),
  grayscale(
    _SelectionEffectConfig(
      icon: AppIcon.effectGrayscale,
      apply: _applyGrayscaleEffect,
    ),
  ),
  saturation(
    _SelectionEffectConfig(
      icon: AppIcon.effectSaturation,
      apply: _applySaturationEffect,
      bipolar: true,
    ),
  ),
  hueRotation(
    _SelectionEffectConfig(
      icon: AppIcon.effectHueRotation,
      apply: _applyHueRotationEffect,
      bipolar: true,
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

  /// Whether this effect is bidirectional: its slider is centred (0 = no
  /// change) and negative vs. positive strength push opposite ways (e.g.
  /// darken vs. brighten, less vs. more contrast, hue ±).
  bool get bipolar => _config.bipolar;

  /// Default UI size value for this effect.
  double get defaultSize => _config.defaultSize;

  /// Returns the integer size value shown for effects that support size control.
  int sizeValue(double size) {
    return _config.sizeValueResolver(size);
  }

  /// Applies this effect to the given [image] and returns the processed result.
  ///
  /// For unipolar effects [strength] runs 0.0 (none) to 1.0 (full authored
  /// strength). For [bipolar] effects it is signed: 0.0 = no change, and the
  /// sign selects the direction (e.g. + brightens, - darkens).
  ///
  /// [size] controls effect-specific block or grain sizing where supported.
  ///
  /// [pixelScale] scales pixel-space parameters (blur radius, block and grain
  /// size) so a downscaled preview proxy matches the full-resolution result.
  Future<ui.Image> apply(
    ui.Image image, {
    double strength = AppEffects.defaultIntensity,
    double? size,
    double pixelScale = AppEffects.defaultPixelScale,
  }) {
    // Bipolar effects map strength directly (symmetric ±1 range); unipolar
    // effects scale up so the slider max reaches double the authored strength.
    final double appliedStrength = _config.bipolar ? strength : strength * AppEffects.intensityAppliedScale;
    final double appliedSize = size ?? defaultSize;
    return _config.apply(image, appliedStrength, appliedSize, pixelScale);
  }
}

int _defaultSelectionEffectSizeValue(double _) {
  return AppEffects.noiseMinCellSize;
}

int _noiseSelectionEffectSizeValue(double size) {
  final double clampedSize = size.clamp(AppEffects.minSize, AppEffects.maxSize);
  return AppEffects.noiseMinCellSize +
      (((AppEffects.noiseMaxCellSize - AppEffects.noiseMinCellSize).toDouble()) * clampedSize).round();
}

int _pixelateSelectionEffectSizeValue(double size) {
  final double clampedSize = size.clamp(AppEffects.minSize, AppEffects.maxSize);
  return AppEffects.pixelateMinBlockSize +
      (((AppEffects.pixelateMaxBlockSize - AppEffects.pixelateMinBlockSize).toDouble()) * clampedSize).round();
}

Future<ui.Image> _applyBlurEffect(
  ui.Image image,
  double strength,
  double _,
  double pixelScale,
) {
  return applyGaussianBlur(image, AppEffects.blurSigma, strength: strength, pixelScale: pixelScale);
}

Future<ui.Image> _applyBrightnessEffect(
  ui.Image image,
  double strength,
  double _,
  double _,
) {
  return applyBrightness(image, strength: strength);
}

Future<ui.Image> _applyContrastEffect(
  ui.Image image,
  double strength,
  double _,
  double _,
) {
  return applyContrast(image, strength: strength);
}

Future<ui.Image> _applyGrayscaleEffect(
  ui.Image image,
  double strength,
  double _,
  double _,
) {
  return applyGrayscale(image, strength: strength);
}

Future<ui.Image> _applyHueRotationEffect(
  ui.Image image,
  double strength,
  double _,
  double _,
) {
  return applyHueRotation(image, strength: strength);
}

/// Bipolar saturation: negative strength desaturates toward gray (strength -1
/// is fully gray); positive strength boosts chroma. Centre (0) is a no-op.
Future<ui.Image> _applySaturationEffect(
  ui.Image image,
  double strength,
  double _,
  double _,
) {
  return applySaturation(image, strength: strength);
}

Future<ui.Image> _applyNoiseEffect(
  ui.Image image,
  double strength,
  double size,
  double pixelScale,
) {
  return applyNoise(image, strength: strength, size: size, pixelScale: pixelScale);
}

Future<ui.Image> _applyPixelateEffect(
  ui.Image image,
  double strength,
  double size,
  double pixelScale,
) {
  return applyPixelate(image, strength: strength, size: size, pixelScale: pixelScale);
}

Future<ui.Image> _applyShadowEffect(
  ui.Image image,
  double strength,
  double _,
  double _,
) {
  return applyShadow(image, strength: strength);
}

/// Bipolar sharpness: negative strength softens (a gentle Gaussian blur using
/// [AppEffects.softenSigma]); positive strength sharpens. Centre (0) is a
/// no-op returning the source image unchanged. Heavy blurring is left to the
/// dedicated Blur effect (which uses the stronger blur sigma and scale).
Future<ui.Image> _applySharpnessEffect(
  ui.Image image,
  double strength,
  double _,
  double pixelScale,
) {
  if (strength == AppEffects.minIntensity) {
    return Future<ui.Image>.value(image);
  }
  if (strength < AppEffects.minIntensity) {
    return applyGaussianBlur(image, AppEffects.softenSigma, strength: -strength, pixelScale: pixelScale);
  }
  return applySharpen(image, strength: strength, pixelScale: pixelScale);
}

Future<ui.Image> _applyVignetteEffect(
  ui.Image image,
  double strength,
  double _,
  double _,
) {
  return applyVignette(image, strength: strength);
}
