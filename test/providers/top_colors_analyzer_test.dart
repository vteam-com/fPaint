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
      // Both layers' shares averaged over the two visible layers.
      expect(red.percentage, closeTo((0.5 + 0.7) / 2, 0.0001));
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

    test('averages over visible layers only, ignoring hidden ones', () {
      final List<LayerProvider> layers = <LayerProvider>[
        _layer(<ColorUsage>[ColorUsage(Colors.red, 0.5)]),
        _layer(<ColorUsage>[ColorUsage(Colors.red, 0.5)]),
        _layer(<ColorUsage>[ColorUsage(Colors.green, 0.9)], isVisible: false),
        _layer(<ColorUsage>[ColorUsage(Colors.green, 0.9)], isVisible: false),
      ];

      final List<ColorUsage> result = analyzer.analyze(layers);

      // Two visible layers at 0.5 each average to 0.5. Dividing by the total
      // layer count instead would dilute this to 0.25.
      expect(result.first.percentage, closeTo(0.5, 0.0001));
    });

    test('returns an empty palette when every layer is hidden', () {
      final List<LayerProvider> layers = <LayerProvider>[
        _layer(<ColorUsage>[ColorUsage(Colors.red, 0.5)], isVisible: false),
      ];

      expect(analyzer.analyze(layers), isEmpty);
    });

    test('never mutates a layer own ColorUsage instances', () {
      final ColorUsage layerRed = ColorUsage(Colors.red, 0.5);
      final List<LayerProvider> layers = <LayerProvider>[
        _layer(<ColorUsage>[layerRed]),
        _layer(<ColorUsage>[ColorUsage(Colors.red, 0.7)]),
      ];

      final List<ColorUsage> result = analyzer.analyze(layers);

      expect(layerRed.percentage, closeTo(0.5, 0.0001));
      expect(identical(result.first, layerRed), isFalse);
    });

    test('is idempotent across repeated analysis', () {
      final List<LayerProvider> layers = <LayerProvider>[
        _layer(<ColorUsage>[ColorUsage(Colors.red, 0.5)]),
        _layer(<ColorUsage>[ColorUsage(Colors.red, 0.7)]),
      ];

      final double first = analyzer.analyze(layers).first.percentage;
      analyzer.analyze(layers);
      final double third = analyzer.analyze(layers).first.percentage;

      // Aggregating into the layers' own instances made the palette grow on
      // every call, eventually exceeding 100%.
      expect(third, closeTo(first, 0.0001));
      expect(third, lessThanOrEqualTo(1.0));
    });

    test('merges duplicate colors within a single layer', () {
      final List<LayerProvider> layers = <LayerProvider>[
        _layer(<ColorUsage>[ColorUsage(Colors.red, 0.2), ColorUsage(Colors.red, 0.3)]),
      ];

      final List<ColorUsage> result = analyzer.analyze(layers);

      expect(result.where((ColorUsage c) => c.color == Colors.red), hasLength(1));
      expect(result.first.percentage, closeTo(0.5, 0.0001));
    });

    test('defaultColors provides the pre-analysis palette', () {
      final List<ColorUsage> defaults = TopColorsAnalyzer.defaultColors;

      expect(defaults.map((ColorUsage c) => c.color), <Color>[AppColors.white, AppColors.black]);
    });
  });
}
