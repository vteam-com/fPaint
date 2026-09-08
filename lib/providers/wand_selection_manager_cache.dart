import 'dart:typed_data';

import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/providers/fill_service.dart';

/// The rasterized-source cache the wand sampler reads and fills.
///
/// A narrow interface so [WandSourceSampler] depends on the caching contract
/// rather than on the concrete request-queue manager that implements it
/// (Dependency Inversion).
abstract class WandSourceCache {
  /// Returns the cached source data when [signature] still matches, else null.
  FillImageData? cachedImageData(int signature);

  /// Stores freshly rasterized source pixels under [signature].
  void storeCache({
    required int signature,
    required Uint8List pixels,
    required int width,
    required int height,
    double canvasScaleX = AppVisual.full,
    double canvasScaleY = AppVisual.full,
  });
}
