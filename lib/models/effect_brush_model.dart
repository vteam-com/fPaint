import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/selection_effect.dart';

/// State for an effect armed as a brush, where the effect is brushed onto the
/// canvas stroke-by-stroke rather than applied to a whole region at once.
///
/// Effects live in the same Brush section as the gesture tools: tapping one
/// arms it here. When [isArmed], canvas strokes commit the [effect] over the
/// brushed band (see AppProvider.commitEffectBrushStroke) instead of drawing
/// colour.
class EffectBrushModel {
  /// The effect armed as a brush, or null when nothing is armed.
  SelectionEffect? effect;

  /// Strength applied by each painted stroke (0..1 for unipolar effects;
  /// -1..1 for bipolar effects, e.g. sharpness/brightness).
  double strength = AppEffects.defaultIntensity;

  /// Size parameter for effects that expose one (e.g. pixelate, noise).
  double size = AppEffects.minSize;

  /// Whether an effect is armed, so a canvas stroke paints it right now.
  bool get isArmed => effect != null;

  /// Arms [newEffect] for painting, resetting to the default strength and its
  /// default size. Bipolar effects brighten/strengthen by default; drag the
  /// strength slider through 0 to reverse.
  void arm(final SelectionEffect newEffect) {
    effect = newEffect;
    strength = AppEffects.defaultIntensity;
    size = newEffect.defaultSize;
  }

  /// Disarms the active paint effect without leaving Paint mode.
  void disarm() {
    effect = null;
  }
}
