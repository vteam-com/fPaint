import 'package:flutter/widgets.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/magnifier_loupe.dart';
import 'package:fpaint/widgets/magnifier_sampling.dart';

/// A widget that displays a magnifying eye dropper for selecting colors from an image.
class MagnifyingEyeDropper extends StatefulWidget {
  /// Creates a [MagnifyingEyeDropper].
  ///
  /// The [layers] parameter specifies the layers provider.
  /// The [pointerPosition] parameter specifies the position of the pointer.
  /// The [pixelPosition] parameter specifies the position of the pixel to sample.
  const MagnifyingEyeDropper({
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
  MagnifyingEyeDropperState createState() => MagnifyingEyeDropperState();
}

/// The state for [MagnifyingEyeDropper].
class MagnifyingEyeDropperState extends State<MagnifyingEyeDropper> with MagnifierSampling<MagnifyingEyeDropper> {
  /// The selected color.
  Color? _selectedColor;
  @override
  void didUpdateWidget(covariant MagnifyingEyeDropper oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pixelPosition != widget.pixelPosition) {
      requestSample();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MagnifierLoupe(
      magnifiedRegion: magnifiedRegion,
      pointerPosition: widget.pointerPosition,
      sampledColor: _selectedColor,
    );
  }

  @override
  Future<VoidCallback> sampleCaption(Offset pixelPosition) async {
    final Color? color = await widget.layers.getColorAtOffset(pixelPosition);
    return () => _selectedColor = color;
  }

  @override
  LayersProvider get samplingLayers => widget.layers;
  @override
  Offset get samplingPixelPosition => widget.pixelPosition;
}
