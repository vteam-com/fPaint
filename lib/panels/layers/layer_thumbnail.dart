import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/providers/layer_provider.dart';
import 'package:fpaint/widgets/image_painter.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// Vertical spacing between the thumbnail and the preview popup.
const double _previewVerticalSpacing = 20.0;

/// Alpha value for the shadow overlay (semi-transparent).
const int _shadowAlpha = 127;

/// Blur radius for the preview popup shadow.
const double _shadowBlurRadius = 8.0;

/// Vertical offset of the shadow.
const double _shadowVerticalOffset = 4.0;

/// Scale multiplier for the preview popup (4x larger than thumbnail).
const double _previewScaleMultiplier = 4.0;

/// Pattern size for the transparent background grid.
const int _transparentPatternSize = 4;

/// A widget that displays a thumbnail of a layer with a large preview on hover.
class LayerThumbnail extends StatefulWidget {
  const LayerThumbnail({
    super.key,
    required this.layer,
  });

  /// The layer to display a thumbnail of.
  final LayerProvider layer;

  @override
  State<LayerThumbnail> createState() => _LayerThumbnailState();
}

class _LayerThumbnailState extends State<LayerThumbnail> {
  bool _isHovering = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    const int patternSize = _transparentPatternSize;
    return LayoutBuilder(
      builder: (final BuildContext _, final BoxConstraints constraints) {
        // Align to transparency pattern grid to ensure proper rendering of the transparency background
        final int size = (constraints.maxWidth / patternSize).floor() * patternSize;

        return CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            onEnter: (_) {
              _isHovering = true;
              _showPreview();
            },
            onExit: (_) {
              _isHovering = false;
              _hidePreview();
            },
            child: SizedBox(
              width: size.toDouble(),
              height: size.toDouble(),
              child: Stack(
                children: <Widget>[
                  const TransparentPaper(patternSize: patternSize),
                  if (widget.layer.thumbnailImage != null)
                    SizedBox(
                      width: size.toDouble(),
                      height: size.toDouble(),
                      child: CustomPaint(
                        painter: ImagePainter(widget.layer.thumbnailImage!),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Computes the vertical offset so the popup stays fully on screen.
  ///
  /// Prefers placing the popup above the thumbnail. If there is not enough
  /// room above, it places it below. If neither side fits, it clamps the
  /// popup flush to the top edge of the overlay.
  double _computeVerticalOffset(final double previewSize) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final OverlayState overlay = Overlay.of(context);
    final RenderBox? overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) {
      return -(previewSize + _previewVerticalSpacing);
    }

    final Offset thumbGlobal = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final double thumbH = box.size.height;
    final double overlayH = overlayBox.size.height;

    // Enough space above?
    if (thumbGlobal.dy >= previewSize + _previewVerticalSpacing) {
      return -(previewSize + _previewVerticalSpacing);
    }

    // Enough space below?
    if (thumbGlobal.dy + thumbH + previewSize + _previewVerticalSpacing <= overlayH) {
      return thumbH + _previewVerticalSpacing;
    }

    // Neither fits cleanly – clamp so popup top sits at the overlay top edge.
    return -thumbGlobal.dy;
  }

  /// Hides the large preview popup.
  void _hidePreview() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Shows the large preview popup when hovering over the thumbnail.
  Future<void> _showPreview() async {
    if (_overlayEntry != null) {
      return;
    }

    await widget.layer.ensureCachePrimed();
    if (!mounted || !_isHovering || _overlayEntry != null) {
      return;
    }

    final double previewHeight = AppLayout.thumbnailMaxHeight * _previewScaleMultiplier;
    final double offsetY = _computeVerticalOffset(previewHeight);
    final ui.Image? previewImage = widget.layer.cachedImage ?? widget.layer.thumbnailImage;
    if (previewImage == null) {
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (final BuildContext _) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0, offsetY),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.grey700,
                width: AppStroke.thin,
              ),
              borderRadius: BorderRadius.circular(AppRadius.small),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.black.withAlpha(_shadowAlpha),
                  blurRadius: _shadowBlurRadius,
                  offset: const Offset(0, _shadowVerticalOffset),
                ),
              ],
            ),
            width: previewHeight,
            height: previewHeight,
            child: Stack(
              children: <Widget>[
                const TransparentPaper(patternSize: _transparentPatternSize),
                SizedBox.expand(
                  child: CustomPaint(
                    painter: ImagePainter(previewImage),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }
}
