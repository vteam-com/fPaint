import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/render_helper.dart';

/// A widget that draws a rectangle with dashed borders and a specified fill color.
class DashedRectangle extends StatelessWidget {
  /// Creates a [DashedRectangle].
  ///
  /// The [fillColor] parameter specifies the color to fill the rectangle with.
  /// The [width] and [height] parameters specify the width and height of the rectangle, respectively.
  const DashedRectangle({
    super.key,
    required this.fillColor,
    this.width = AppLayout.previewRegionSize,
    this.height = AppLayout.previewRegionSize,
  });

  /// The color to fill the rectangle with.
  final Color fillColor;

  /// The height of the rectangle.
  final double height;

  /// The width of the rectangle.
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _DashedRectanglePainter(fillColor: fillColor),
    );
  }
}

/// A custom painter that draws a rectangle with dashed borders and a specified fill color.
class _DashedRectanglePainter extends CustomPainter {
  /// Creates a [_DashedRectanglePainter].
  ///
  /// The [fillColor] parameter specifies the color to fill the rectangle with.
  _DashedRectanglePainter({required this.fillColor});

  /// The color to fill the rectangle with.
  final Color fillColor;

  /// The width of each dash.
  final double dashWidth = AppStroke.regular;

  /// The space between each dash.
  final double dashSpace = 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Create a paint object for filling the rectangle
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Draw the filled rectangle
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);

    // Create paint objects for the black and white dashed borders
    final Paint blackPaint = Paint()
      ..color = AppColors.black
      ..strokeWidth = AppStroke.regular
      ..style = PaintingStyle.stroke;

    final Paint whitePaint = Paint()
      ..color = AppColors.white
      ..strokeWidth = AppStroke.regular
      ..style = PaintingStyle.stroke;

    // Draw dashed borders, one side at a time (top, bottom, left, right) so
    // the corner overlaps keep their original stacking order.
    final List<(Offset, Offset)> sides = <(Offset, Offset)>[
      (Offset.zero, Offset(size.width, 0)),
      (Offset(0, size.height), Offset(size.width, size.height)),
      (Offset.zero, Offset(0, size.height)),
      (Offset(size.width, 0), Offset(size.width, size.height)),
    ];
    for (final (Offset start, Offset end) in sides) {
      drawTwoToneDashedPath(
        canvas,
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(end.dx, end.dy),
        dashLength: dashWidth,
        gap: dashSpace,
        firstPaint: blackPaint,
        secondPaint: whitePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
