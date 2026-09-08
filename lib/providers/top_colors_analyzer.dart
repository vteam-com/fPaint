import 'dart:ui' show Color;

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
  /// Each color's share is averaged over the number of *visible* layers (hidden
  /// layers contribute nothing and must not dilute the average), and the result
  /// is capped at [AppLimits.topColorCount].
  ///
  /// Aggregation always builds new [ColorUsage] instances. [ColorUsage] is
  /// mutable, so accumulating into a layer's own instance would corrupt that
  /// layer's [LayerProvider.topColorsUsed] and make every re-analysis inflate
  /// the palette further.
  List<ColorUsage> analyze(List<LayerProvider> layers) {
    final List<LayerProvider> visibleLayers = layers.where((LayerProvider layer) => layer.isVisible).toList();
    final int visibleLayerCount = visibleLayers.length;
    if (visibleLayerCount == 0) {
      return <ColorUsage>[];
    }

    final Map<Color, ColorUsage> aggregatedByColor = <Color, ColorUsage>{};
    for (final LayerProvider layer in visibleLayers) {
      for (final ColorUsage colorUsed in layer.topColorsUsed) {
        final double share = colorUsed.percentage / visibleLayerCount;
        final ColorUsage? existingColor = aggregatedByColor[colorUsed.color];
        if (existingColor == null) {
          aggregatedByColor[colorUsed.color] = ColorUsage(colorUsed.color, share);
        } else {
          existingColor.percentage += share;
        }
      }
    }

    final List<ColorUsage> aggregated = aggregatedByColor.values.toList()
      ..sort((ColorUsage a, ColorUsage b) => b.percentage.compareTo(a.percentage));
    return aggregated.take(AppLimits.topColorCount).toList();
  }
}
