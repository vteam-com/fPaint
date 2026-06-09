/// Constants for selection region effects.
class AppEffects {
  /// Gaussian blur sigma for the blur effect.
  static const double blurSigma = 6.0;

  /// Gaussian blur sigma for the soften (edge softener) effect.
  static const double softenSigma = 2.0;

  /// Gaussian blur sigma used as the base for the sharpen (unsharp-mask) effect.
  static const double sharpenBlurSigma = 1.5;

  /// Strength multiplier for the unsharp-mask sharpen effect.
  static const double sharpenAmount = 1.5;

  /// Downscale factor for the pixelation effect (pixels are grouped into blocks).
  static const int pixelateBlockSize = 8;

  /// Minimum block size exposed by the pixelation size slider.
  static const int pixelateMinBlockSize = 2;

  /// Maximum block size exposed by the pixelation size slider.
  static const int pixelateMaxBlockSize = 100;

  /// Default UI size value for pixelation, mapped to the authored block size.
  static const double pixelateDefaultSize =
      (pixelateBlockSize - pixelateMinBlockSize) / (pixelateMaxBlockSize - pixelateMinBlockSize);

  /// Total range of random noise values added to each channel.
  static const int noiseRange = 51;

  /// Offset subtracted from the random noise to center it around zero.
  static const int noiseOffset = 25;

  /// Minimum noise grain size exposed by the size slider.
  static const int noiseMinCellSize = 1;

  /// Maximum noise grain size exposed by the size slider.
  static const int noiseMaxCellSize = 12;

  /// Default UI size value for noise, mapped to the previous per-pixel grain.
  static const double noiseDefaultSize = 0.0;

  /// Number of color channels processed (R, G, B — alpha is preserved).
  static const int rgbChannelCount = 3;

  /// Byte index of the alpha channel within an RGBA pixel.
  static const int alphaChannelIndex = 3;

  /// Strength of the vignette darkening at the edges (0 = none, 1 = full black).
  static const double vignetteStrength = 0.75;

  /// Maximum brightness offset added per channel (0–255 scale).
  static const int brightnessOffset = 100;

  /// Maximum contrast multiplier applied to each channel.
  static const double contrastMax = 2.0;

  /// Maximum hue rotation in degrees.
  static const double hueRotationMax = 180.0;

  /// Degrees in a full hue rotation.
  static const double hueFullCircle = 360.0;

  /// Maximum shadow darkening strength.
  static const double shadowDarkening = 0.6;

  /// Shadow midtone threshold (0–255), below which darkening is applied.
  static const int shadowMidtone = 128;

  /// ITU-R BT.601 luma coefficient for the red channel.
  static const double lumaRed = 0.2126;

  /// ITU-R BT.601 luma coefficient for the green channel.
  static const double lumaGreen = 0.7152;

  /// ITU-R BT.601 luma coefficient for the blue channel.
  static const double lumaBlue = 0.0722;

  /// Default effect intensity shown to the user when the slider first opens.
  ///
  /// UI range is 0.0-1.0, where 0.5 maps to the previously authored full strength.
  static const double defaultIntensity = 0.5;

  /// Minimum effect size slider value.
  static const double minSize = 0.0;

  /// Maximum effect size slider value.
  static const double maxSize = 1.0;

  /// Minimum effect intensity (no visible change).
  static const double minIntensity = 0.0;

  /// Maximum effect intensity shown in the UI slider.
  static const double maxIntensity = 1.0;

  /// Multiplier that maps UI intensity to the actual effect strength.
  ///
  /// With this mapping, 50% UI intensity equals the previously authored full strength,
  /// and 100% UI intensity applies 2x that strength when effect math supports it.
  static const double intensityAppliedScale = 2.0;
}
