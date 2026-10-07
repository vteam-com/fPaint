import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/magnifier_loupe.dart';

/// Live sampling shared by the on-canvas loupes (eyedropper, layer picker).
///
/// Each sample composites only the few pixels the loupe magnifies, via
/// [LayersProvider.captureCompositeRegion], plus whatever the loupe captions
/// ([sampleCaption]). Nothing full-canvas is rendered or read back: doing that
/// per pointer move is what exhausted memory on large canvases.
///
/// Samples are serialized: pointer moves arrive far faster than a sample
/// completes, so moves that land mid-sample collapse into one follow-up sample
/// of the latest position instead of stacking renders in flight. Every
/// completed sample is shown, so the loupe tracks a drag one sample behind.
mixin MagnifierSampling<T extends StatefulWidget> on State<T> {
  /// Whether a sample is currently running.
  bool _isSampling = false;

  /// Whether the crosshair moved while [_isSampling].
  bool _isResampleQueued = false;

  /// The magnified region around the crosshair. Owned here: replaced images
  /// are disposed, and the last one is disposed with the state.
  ui.Image? magnifiedRegion;

  /// The layers to sample.
  LayersProvider get samplingLayers;

  /// The canvas pixel under the crosshair.
  Offset get samplingPixelPosition;

  /// Samples the caption data at [pixelPosition] and returns the state
  /// mutation that applies it; it runs inside the same `setState` that swaps
  /// in the new [magnifiedRegion], so loupe and caption never disagree.
  Future<VoidCallback> sampleCaption(Offset pixelPosition);

  @override
  void initState() {
    super.initState();
    requestSample();
  }

  @override
  void dispose() {
    magnifiedRegion?.dispose();
    magnifiedRegion = null;
    super.dispose();
  }

  /// Samples the current crosshair position, or queues one follow-up sample
  /// when a sample is already running.
  Future<void> requestSample() async {
    if (_isSampling) {
      _isResampleQueued = true;
      return;
    }

    _isSampling = true;
    try {
      do {
        _isResampleQueued = false;
        await _sampleOnce();
      } while (_isResampleQueued && mounted);
    } finally {
      _isSampling = false;
    }
  }

  /// Renders the magnified region and the caption for the current crosshair
  /// pixel and swaps them in together. Results landing after unmount are
  /// disposed instead of shown.
  Future<void> _sampleOnce() async {
    final Offset pixelPosition = samplingPixelPosition;
    // The region and the caption are independent renders, so they run
    // concurrently rather than paying their GPU round trips back to back.
    final (ui.Image region, VoidCallback applyCaption) = await (
      samplingLayers.captureCompositeRegion(MagnifierLoupe.regionAround(pixelPosition)),
      sampleCaption(pixelPosition),
    ).wait;
    // A sample overtaken by a newer move is still shown: during a drag every
    // sample is overtaken, so discarding them starved the loupe until the
    // pointer stopped. The queued follow-up then catches up to the latest move.
    if (!mounted) {
      region.dispose();
      return;
    }

    // Swap and dispose in one synchronous step: the rebuild hands the painter
    // the new image before the next paint, so the old one is never drawn after
    // it is freed.
    setState(() {
      magnifiedRegion?.dispose();
      magnifiedRegion = region;
      applyCaption();
    });
  }
}
