import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/magnifier_loupe.dart';

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
class MagnifyingEyeDropperState extends State<MagnifyingEyeDropper> {
  /// Monotonic id used to ignore stale async color-sampling results.
  int _colorSampleRequestId = 0;

  /// The selected color.
  Color? _selectedColor;

  /// The size of the region.
  final double regionSize = AppLayout.previewRegionSize;

  @override
  void initState() {
    super.initState();
    _updateColor();
  }

  @override
  void didUpdateWidget(covariant MagnifyingEyeDropper oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pixelPosition != widget.pixelPosition || oldWidget.layers.cachedImage != widget.layers.cachedImage) {
      _updateColor();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? sourceImage = widget.layers.cachedImage;
    if (sourceImage == null) {
      return const SizedBox();
    }

    return MagnifierLoupe(
      sourceImage: sourceImage,
      pointerPosition: widget.pointerPosition,
      pixelPosition: widget.pixelPosition,
      sampledColor: _selectedColor,
    );
  }

  /// Updates the selected color.
  void _updateColor() async {
    if (widget.layers.cachedImage == null) {
      if (mounted && _selectedColor != null) {
        setState(() {
          _selectedColor = null;
        });
      }
      return;
    }

    final int requestId = ++_colorSampleRequestId;

    final Color? color = await widget.layers.getColorAtOffset(
      widget.pixelPosition,
      useCachedImage: true,
    );

    if (!mounted || requestId != _colorSampleRequestId || color == _selectedColor) {
      return;
    }

    setState(() {
      _selectedColor = color;
    });
  }
}
