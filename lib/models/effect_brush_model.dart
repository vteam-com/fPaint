import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/selection_effect.dart';

/// State for the Adjust family's Paint mode, where an effect is brushed onto
/// the canvas stroke-by-stroke rather than applied to a whole region at once.
///
/// When [isArmed], canvas strokes commit the [effect] over the brushed band
/// (see AppProvider.commitEffectBrushStroke) instead of drawing colour.
class EffectBrushModel {
  /// Whether the Adjust family is in Paint mode (vs. the default Apply mode).
  bool paintMode = false;

  /// The effect armed for painting, or null when nothing is armed.
  SelectionEffect? effect;

  /// Strength applied by each painted stroke (0..1).
  double strength = AppEffects.defaultIntensity;

  /// Size parameter for effects that expose one (e.g. pixelate, noise).
  double size = AppEffects.minSize;

  /// Whether a canvas stroke should paint an effect right now.
  bool get isArmed => paintMode && effect != null;

  /// Arms [newEffect] for painting, seeding its default size.
  void arm(final SelectionEffect newEffect) {
    effect = newEffect;
    size = newEffect.defaultSize;
  }

  /// Disarms the active paint effect without leaving Paint mode.
  void disarm() {
    effect = null;
  }
}
