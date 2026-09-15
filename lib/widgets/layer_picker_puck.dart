import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/app_text.dart';
import 'package:fpaint/widgets/magnifier_loupe.dart';

/// An on-canvas puck for the single-shot pick-layer gesture.
///
/// It magnifies the pixels under the crosshair like the eyedropper does, and
/// captions them with the name of the topmost visible layer that owns the
/// sampled pixel. Showing the layer before the pick commits is the whole point
/// of the puck: on a dense composite the owning layer is otherwise invisible
/// until after it has been selected, and on touch the finger covers the target.
class LayerPickerPuck extends StatefulWidget {
  /// Creates a [LayerPickerPuck].
  ///
  /// The [layers] parameter specifies the layers provider.
  /// The [pointerPosition] parameter specifies the position of the pointer.
  /// The [pixelPosition] parameter specifies the canvas pixel to sample.
  const LayerPickerPuck({
    required this.layers,
    required this.pointerPosition,
    required this.pixelPosition,
    super.key,
  });

  /// The layers provider.
  final LayersProvider layers;

  /// The position of the pixel to sample.
  final Offset pixelPosition;

  /// The position of the pointer.
  final Offset pointerPosition;

  @override
  State<LayerPickerPuck> createState() => _LayerPickerPuckState();
}

class _LayerPickerPuckState extends State<LayerPickerPuck> {
  /// The name of the layer owning the sampled pixel, or null when none does.
  String? _owningLayerName;

  /// Monotonic id used to ignore stale async sampling results.
  int _sampleRequestId = 0;

  /// The color under the crosshair, previewing what the pick applies.
  Color? _sampledColor;

  /// The diameter of the magnified region.
  final double regionSize = AppLayout.previewRegionSize;
  @override
  void initState() {
    super.initState();
    _updateSample();
  }

  @override
  void didUpdateWidget(covariant LayerPickerPuck oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pixelPosition != widget.pixelPosition || oldWidget.layers.cachedImage != widget.layers.cachedImage) {
      _updateSample();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? sourceImage = widget.layers.cachedImage;
    if (sourceImage == null) {
      return const SizedBox();
    }

    final String? name = _owningLayerName;

    return MagnifierLoupe(
      sourceImage: sourceImage,
      pointerPosition: widget.pointerPosition,
      pixelPosition: widget.pixelPosition,
      sampledColor: _sampledColor,
      caption: name == null ? null : _buildLayerNameCaption(name),
    );
  }

  /// Builds the layer-name caption pinned under the magnified region.
  Widget _buildLayerNameCaption(String name) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: AppSpacing.thin,
        ),
        child: AppText(
          name,
          variant: AppTextVariant.label,
          color: AppColors.white,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Refreshes the sampled color and the owning layer name for the current
  /// crosshair position, dropping results superseded by a newer sample.
  Future<void> _updateSample() async {
    if (widget.layers.cachedImage == null) {
      if (mounted && (_sampledColor != null || _owningLayerName != null)) {
        setState(() {
          _sampledColor = null;
          _owningLayerName = null;
        });
      }
      return;
    }

    final int requestId = ++_sampleRequestId;

    final Color? color = await widget.layers.getColorAtOffset(
      widget.pixelPosition,
      useCachedImage: true,
    );
    if (!mounted || requestId != _sampleRequestId) {
      return;
    }

    final LayerProvider? owningLayer = await widget.layers.findTopmostOpaqueLayerAt(widget.pixelPosition);
    if (!mounted || requestId != _sampleRequestId) {
      return;
    }

    final String? name = owningLayer?.name;
    if (color == _sampledColor && name == _owningLayerName) {
      return;
    }

    setState(() {
      _sampledColor = color;
      _owningLayerName = name;
    });
  }
}
