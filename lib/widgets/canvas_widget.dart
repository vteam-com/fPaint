import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';

class CanvasWidget extends StatefulWidget {
  const CanvasWidget({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.child,
  });
  final double canvasWidth;
  final double canvasHeight;
  final Widget child;

  @override
  CanvasWidgetState createState() => CanvasWidgetState();
}

class CanvasWidgetState extends State<CanvasWidget> {
  @override
  Widget build(BuildContext context) {
    AppModel appModel = AppModel.get(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewportWidth = constraints.maxWidth;
        final double viewportHeight = constraints.maxHeight;

        final double scaledWidth = widget.canvasWidth * appModel.canvas.scale;
        final double scaledHeight = widget.canvasHeight * appModel.canvas.scale;

        // Ensure the canvas is always centered when it's smaller than the viewport
        final double centerX = max(0, (viewportWidth - scaledWidth) / 2);
        final double centerY = max(0, (viewportHeight - scaledHeight) / 2);

        return GestureDetector(
          onScaleStart: (details) {
            if (details.pointerCount == 2) {
              appModel.lastFocalPoint = details.focalPoint;
            }
          },
          onScaleUpdate: (details) {
            setState(() {
              if (details.pointerCount == 2) {
                final double newScale =
                    (appModel.canvas.scale * (1 + (details.scale - 1) * 0.005))
                        .clamp(0.5, 4.0);

                if (appModel.lastFocalPoint != null) {
                  final Offset focalPointDelta =
                      details.focalPoint - appModel.lastFocalPoint!;
                  final Offset scaleAdjustment =
                      (appModel.offset - details.focalPoint) *
                          (newScale / appModel.canvas.scale - 1);

                  appModel.offset += focalPointDelta + scaleAdjustment;
                }

                appModel.canvas.scale = newScale;
                appModel.lastFocalPoint = details.focalPoint;
              }
            });
          },
          child: ClipRect(
            child: Transform(
              transform: Matrix4.identity()
                ..translate(
                  appModel.offset.dx + centerX,
                  appModel.offset.dy + centerY,
                )
                ..scale(appModel.canvas.scale),
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: max(widget.canvasWidth, viewportWidth),
                height: max(widget.canvasHeight, viewportHeight),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
