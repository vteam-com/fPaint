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
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset? _lastFocalPoint;
  double _lastScale = 1.0;
  Offset? _panStartFocalPoint;

  @override
  void initState() {
    super.initState();
    final appModel = AppModel.get(context);
    _scale = appModel.canvas.scale;
    _offset = appModel.offset;
  }

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.get(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewportWidth = constraints.maxWidth;
        final double viewportHeight = constraints.maxHeight;

        final double scaledWidth = widget.canvasWidth * _scale;
        final double scaledHeight = widget.canvasHeight * _scale;

        final double centerX = max(0, (viewportWidth - scaledWidth) / 2);
        final double centerY = max(0, (viewportHeight - scaledHeight) / 2);

        return GestureDetector(
          onScaleStart: (details) {
            if (details.pointerCount == 2) {
              _lastFocalPoint = details.focalPoint;
              _lastScale = _scale;
              _panStartFocalPoint =
                  details.focalPoint; //Initialize PanStart on 2 finger
            }
          },
          onScaleUpdate: (details) {
            if (details.pointerCount == 2) {
              setState(() {
                if (_lastFocalPoint != null && _panStartFocalPoint != null) {
                  if (details.scale != 1.0) {
                    // Scaling
                    _scale = (_lastScale * details.scale).clamp(0.5, 4.0);
                    final Offset focalPointDelta =
                        details.focalPoint - _lastFocalPoint!;
                    _offset += focalPointDelta -
                        focalPointDelta * (_scale / _lastScale);
                    _lastFocalPoint = details.focalPoint;
                  } else {
                    // Panning
                    final Offset delta =
                        details.focalPoint - _panStartFocalPoint!;
                    _offset += delta;
                    _panStartFocalPoint = details.focalPoint;
                  }
                }
                // Update appModel with the new scale and offset
                appModel.canvas.scale = _scale;
                appModel.offset = _offset;
              });
            }
          },
          child: ClipRect(
            child: Transform(
              transform: Matrix4.identity()
                ..translate(
                  _offset.dx + centerX,
                  _offset.dy + centerY,
                )
                ..scale(_scale),
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
