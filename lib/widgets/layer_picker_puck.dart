import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/app_text.dart';
import 'package:fpaint/widgets/magnifier_loupe.dart';
import 'package:fpaint/widgets/magnifier_sampling.dart';

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

class _LayerPickerPuckState extends State<LayerPickerPuck> with MagnifierSampling<LayerPickerPuck> {
  /// The name of the layer owning the sampled pixel, or null when none does.
  String? _owningLayerName;

  /// The color under the crosshair, previewing what the pick applies.
  Color? _sampledColor;
  @override
  void didUpdateWidget(covariant LayerPickerPuck oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pixelPosition != widget.pixelPosition) {
      requestSample();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? name = _owningLayerName;

    return MagnifierLoupe(
      magnifiedRegion: magnifiedRegion,
      pointerPosition: widget.pointerPosition,
      sampledColor: _sampledColor,
      caption: name == null ? null : _buildLayerNameCaption(name),
    );
  }

  @override
  Future<VoidCallback> sampleCaption(Offset pixelPosition) async {
    final LayerPixelPick pick = await widget.layers.pickPixelAt(pixelPosition);
    return () {
      _sampledColor = pick.color;
      _owningLayerName = pick.owningLayer?.name;
    };
  }

  @override
  LayersProvider get samplingLayers => widget.layers;
  @override
  Offset get samplingPixelPosition => widget.pixelPosition;

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
}
