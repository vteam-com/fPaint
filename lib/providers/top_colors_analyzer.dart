import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/providers/layer_provider.dart';

/// Aggregates the most-used colors across a stack of layers.
///
/// Pulled out of `LayersProvider` because palette analysis is a distinct
/// responsibility from owning the layer stack: it only reads layers and returns
/// a ranked list, so it carries no state and needs no provider to be tested
/// (Single Responsibility).
class TopColorsAnalyzer {
  const TopColorsAnalyzer();

  /// The palette shown before any canvas analysis has run.
  static List<ColorUsage> get defaultColors => <ColorUsage>[
    ColorUsage(AppColors.white, 1),
    ColorUsage(AppColors.black, 1),
  ];

  /// Returns the most used colors across the visible layers in [layers].
  ///
  /// Each layer contributes its own per-layer usage, averaged over the total
  /// layer count, and the result is capped at [AppLimits.topColorCount].
  List<ColorUsage> analyze(List<LayerProvider> layers) {
    final List<ColorUsage> aggregated = <ColorUsage>[];
    final int totalLayers = layers.length;
    if (totalLayers == 0) {
      return aggregated;
    }

    for (final LayerProvider layer in layers) {
      if (!layer.isVisible) {
        continue;
      }
      for (final ColorUsage colorUsed in layer.topColorsUsed) {
        final ColorUsage existingColor = aggregated.firstWhere(
          (ColorUsage c) => c.color == colorUsed.color,
          orElse: () => colorUsed,
        );
        if (existingColor == colorUsed) {
          aggregated.add(colorUsed);
        } else {
          existingColor.percentage += colorUsed.percentage / totalLayers;
        }
      }
    }

    aggregated.sort(
      (ColorUsage a, ColorUsage b) => b.percentage.compareTo(a.percentage),
    );
    return aggregated.take(AppLimits.topColorCount).toList();
  }
}
