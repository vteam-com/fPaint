import 'package:fpaint/constants/app_limits.dart';
import 'package:fpaint/constants/app_math.dart';

/// Shared sizing tokens for halftone fills.
class AppHalftone {
  static const int defaultDotSizePercent = AppLimits.percentMax ~/ AppMath.pair;
  static const int maxRenderDotCount = 4096;
  static const double dotSpacing = 10.0;
  static const double maxDotRadiusFactor = 0.45;
  static const double minDotIntensity = 0.05;
}
