import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/color_helper.dart';

/// Stores a bounded most-recently-used palette with required neutral colors.
class RecentColors extends ChangeNotifier {
  static const List<Color> _requiredColors = <Color>[
    AppColors.white,
    AppColors.grey,
    AppColors.black,
  ];

  List<Color> colors = List<Color>.of(_requiredColors);

  /// Promotes [color] while keeping the required colors in the list.
  void record(Color color) {
    final List<Color> customColors = <Color>[
      if (!_requiredColors.contains(color)) color,
      ...colors.where((Color recentColor) => recentColor != color && !_requiredColors.contains(recentColor)),
    ].take(AppLimits.recentColorCount - _requiredColors.length).toList();
    colors = <Color>[...customColors, ..._requiredColors];
    notifyListeners();
  }

  /// Returns recent colors first, followed by distinct top-used colors.
  List<ColorUsage> prioritizeTopColors(List<ColorUsage> topColors) {
    final List<ColorUsage> prioritizedColors = colors
        .map(
          (Color recentColor) => topColors.firstWhere(
            (ColorUsage colorUsage) => colorUsage.color == recentColor,
            orElse: () => ColorUsage(recentColor, AppVisual.full),
          ),
        )
        .toList();
    final int remainingCount = AppLimits.topColorCount - prioritizedColors.length;
    prioritizedColors.addAll(
      topColors.where((ColorUsage colorUsage) => !colors.contains(colorUsage.color)).take(remainingCount),
    );
    return prioritizedColors;
  }
}
