// ignore: fcheck_one_class_per_file
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/draw_rect.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';
import 'package:vector_math/vector_math_64.dart' as vm64;

/// A widget that displays a magnifying eye dropper for selecting colors from an image.
class MagnifyingEyeDropper extends StatefulWidget {
  /// Creates a [MagnifyingEyeDropper].
  ///
  /// The [layers] parameter specifies the layers provider.
  /// The [pointerPosition] parameter specifies the position of the pointer.
  /// The [pixelPosition] parameter specifies the position of the pixel to sample.
  /// The [onColorPicked] parameter is a callback that is called when a color is picked.
  /// The [onClosed] parameter is a callback that is called when the eye dropper is closed.
  const MagnifyingEyeDropper({
    required this.layers,
    required this.pointerPosition,
    required this.pixelPosition,
    required this.onColorPicked,
    required this.onClosed,
    super.key,
  });

  /// The layers provider.
  final LayersProvider layers;

  /// A callback that is called when the eye dropper is closed.
  final void Function() onClosed;

  /// A callback that is called when a color is picked.
  final void Function(Color color) onColorPicked;

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

  /// The size of the button.
  final double buttonSize = AppSpacing.largest;

  /// The magnification factor.
  final double magnifyFactor = AppInteraction.magnifierScale;

  /// The size of the region.
  final double regionSize = AppLayout.previewRegionSize;

  /// The size of the spacer.
  final double spacer = AppSpacing.small;

  /// The total height of the widget.
  late final double totalHeightOfTheWidget = buttonSize + spacer + regionSize + spacer + buttonSize;

  /// The width of the widget.
  final double widgetWidth = AppLayout.magnifierWidgetWidth;
  @override
  void initState() {
    super.initState();
    _updateColor();
  }

  @override
  void didUpdateWidget(covariant final MagnifyingEyeDropper oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pixelPosition != widget.pixelPosition || oldWidget.layers.cachedImage != widget.layers.cachedImage) {
      _updateColor();
    }
  }

  @override
  Widget build(final BuildContext context) {
    if (widget.layers.cachedImage == null) {
      return const SizedBox();
    }

    final double offsetFromCenter = (widgetWidth / 2) / magnifyFactor;

    final ui.Rect region = Rect.fromLTWH(
      widget.pixelPosition.dx - offsetFromCenter,
      widget.pixelPosition.dy - offsetFromCenter,
      offsetFromCenter,
      offsetFromCenter,
    );

    final ui.Image croppedImage = cropImage(widget.layers.cachedImage!, region);

    // Magnifying Glass Effect
    return Positioned(
      left: widget.pointerPosition.dx - (widgetWidth),
      top: widget.pointerPosition.dy - (totalHeightOfTheWidget / AppMath.pair),
      child: Column(
        spacing: spacer.toDouble(),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          //
          // Cancel 'X'
          //
          buildOverlayCircleButton(
            key: Keys.magnifyingEyeDropperCloseButton,
            tooltip: context.l10n.cancel,
            icon: AppIcon.close,
            contentSemantic: AppButtonContentSemantic.dangerous,
            cursor: SystemMouseCursors.click,
            onTap: widget.onClosed,
          ),

          //
          // Show Color
          //
          SizedBox(
            width: regionSize,
            height: regionSize,
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                SizedBox(
                  width: regionSize,
                  height: regionSize,
                  child: CustomPaint(
                    painter: MagnifyingGlassPainter(
                      croppedImage: croppedImage,
                      color: _selectedColor ?? AppColors.black,
                    ),
                  ),
                ),
                DashedRectangle(
                  fillColor: _selectedColor ?? AppColors.transparent,
                  width: AppLayout.magnifierTargetSize,
                  height: AppLayout.magnifierTargetSize,
                ),
              ],
            ),
          ),

          //
          // Confirmed CheckBox
          //
          buildOverlayCircleButton(
            key: Keys.magnifyingEyeDropperConfirmButton,
            tooltip: context.l10n.apply,
            icon: AppIcon.check,
            contentSemantic: AppButtonContentSemantic.enabled,
            cursor: SystemMouseCursors.click,
            onTap: () {
              final Color? selectedColor = _selectedColor;
              if (selectedColor == null) {
                return;
              }
              widget.onColorPicked(selectedColor);
            },
          ),
        ],
      ),
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

/// Paints the image.
class ImagePainter extends CustomPainter {
  /// Creates an [ImagePainter].
  ImagePainter(this.image);

  /// The image to paint.
  final ui.Image image;

  @override
  void paint(final Canvas canvas, final Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant final CustomPainter oldDelegate) => false;
}

/// Draws the magnifying glass.
class MagnifyingGlassPainter extends CustomPainter {
  /// Creates a [MagnifyingGlassPainter].
  MagnifyingGlassPainter({
    required this.croppedImage,
    required this.color,
  });

  /// The cropped image.
  final ui.Image croppedImage;

  /// The color.
  final Color color;

  @override
  void paint(final Canvas canvas, final Size size) {
    const double scaleFactor = AppInteraction.magnifierImageScale;

    final Paint paint = Paint()
      ..shader = ImageShader(
        croppedImage,
        TileMode.clamp,
        TileMode.clamp,
        (Matrix4.identity()..scaleByVector3(vm64.Vector3.all(scaleFactor))).storage,
      );

    canvas.drawCircle(
      Offset(size.width / AppMath.pair, size.height / AppMath.pair),
      size.width / AppMath.pair,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width / AppMath.pair, size.height / AppMath.pair),
      size.width / AppMath.pair,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.regular
        ..color = AppColors.black,
    );
    canvas.drawCircle(
      Offset(size.width / AppMath.pair, size.height / AppMath.pair),
      (size.width / AppMath.pair) - AppStroke.thin,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.regular
        ..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(covariant final CustomPainter oldDelegate) => true;
}
