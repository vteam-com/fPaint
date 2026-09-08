import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/providers/layer_provider.dart';
import 'package:fpaint/providers/top_colors_analyzer.dart';
import 'package:material_ui/material_ui.dart';

/// Builds a layer whose per-layer palette is [colors].
LayerProvider _layer(
  List<ColorUsage> colors, {
  bool isVisible = true,
  String name = 'Layer',
}) {
  final LayerProvider layer = LayerProvider(
    name: name,
    size: const Size(100, 100),
    onThumbnailChanged: () {},
    isVisible: isVisible,
  );
  layer.topColorsUsed = colors;
  return layer;
}

void main() {
  const TopColorsAnalyzer analyzer = TopColorsAnalyzer();

  group('TopColorsAnalyzer', () {
    test('returns an empty palette for no layers', () {
      expect(analyzer.analyze(<LayerProvider>[]), isEmpty);
    });

    test('aggregates a shared color across layers', () {
      final List<LayerProvider> layers = <LayerProvider>[
        _layer(<ColorUsage>[ColorUsage(Colors.red, 0.5), ColorUsage(Colors.blue, 0.3)]),
        _layer(<ColorUsage>[ColorUsage(Colors.red, 0.7), ColorUsage(Colors.green, 0.2)]),
      ];

      final List<ColorUsage> result = analyzer.analyze(layers);

      final ColorUsage red = result.firstWhere((ColorUsage c) => c.color == Colors.red);
      // 0.5 plus the second layer's 0.7 averaged over the two layers.
      expect(red.percentage, closeTo(0.85, 0.0001));
      expect(result.map((ColorUsage c) => c.color), contains(Colors.blue));
      expect(result.map((ColorUsage c) => c.color), contains(Colors.green));
    });

    test('skips hidden layers', () {
      final List<LayerProvider> layers = <LayerProvider>[
        _layer(<ColorUsage>[ColorUsage(Colors.red, 0.5)]),
        _layer(<ColorUsage>[ColorUsage(Colors.green, 0.9)], isVisible: false),
      ];

      final List<ColorUsage> result = analyzer.analyze(layers);

      expect(result.map((ColorUsage c) => c.color), contains(Colors.red));
      expect(result.map((ColorUsage c) => c.color), isNot(contains(Colors.green)));
    });

    test('orders the palette by descending usage', () {
      final List<LayerProvider> layers = <LayerProvider>[
        _layer(<ColorUsage>[
          ColorUsage(Colors.red, 0.1),
          ColorUsage(Colors.green, 0.9),
          ColorUsage(Colors.blue, 0.5),
        ]),
      ];

      final List<ColorUsage> result = analyzer.analyze(layers);

      expect(result.first.color, Colors.green);
      expect(result.last.color, Colors.red);
    });

    test('caps the palette at the configured color count', () {
      final List<ColorUsage> many = <ColorUsage>[
        for (int i = 0; i < AppLimits.topColorCount + 5; i++) ColorUsage(Color(0xFF000000 + i), i / 100),
      ];

      expect(analyzer.analyze(<LayerProvider>[_layer(many)]), hasLength(AppLimits.topColorCount));
    });

    test('defaultColors provides the pre-analysis palette', () {
      final List<ColorUsage> defaults = TopColorsAnalyzer.defaultColors;

      expect(defaults.map((ColorUsage c) => c.color), <Color>[AppColors.white, AppColors.black]);
    });
  });
}
