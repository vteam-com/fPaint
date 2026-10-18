import 'dart:ui' as ui;

import 'package:fpaint/providers/layer_provider.dart';

/// One layer's lifted selection content during an "All layers" transform
/// session: the pixels clipped from [layer], sized to the selection bounds.
class CrossLayerLiftEntry {
  CrossLayerLiftEntry({
    required this.layer,
    required this.image,
  });

  /// The layer the lifted content came from and commits back onto.
  final LayerProvider layer;

  /// The layer's pixels clipped to the selection, selection-bounds sized.
  final ui.Image image;
}
