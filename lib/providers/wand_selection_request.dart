import 'package:flutter/widgets.dart';

/// A single queued magic-wand selection request.
@immutable
class WandSelectionRequest {
  const WandSelectionRequest({
    required this.position,
    required this.sampleAllLayers,
    required this.version,
  });

  /// Pointer position, in canvas units, where the wand was triggered.
  final Offset position;

  /// Whether the request should sample all visible layers.
  final bool sampleAllLayers;

  /// Monotonic request version captured when the request was queued.
  final int version;
}
