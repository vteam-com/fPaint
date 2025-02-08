import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';

/// Provides a canvas widget that supports scaling and panning.
///
/// The [CanvasWidget] is a stateful widget that allows the user to scale and pan the content
/// within a bounded canvas area. It manages the scaling and panning state, and updates the
/// [AppModel] with the current scale and offset values.
///
/// The [CanvasWidget] takes in the [canvasWidth], [canvasHeight], and [child] widgets to be
/// displayed within the canvas. The [child] widget is transformed based on the current scale
/// and offset values.
///
/// The scaling and panning behavior is implemented using the [GestureDetector] widget, which
/// listens for scale and pan gestures from the user. The scale and offset values are updated
/// accordingly, and the [AppModel] is updated to persist the changes.

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
    final appModel = AppModel.of(context);
    _scale = appModel.canvas.scale;
    _offset = appModel.offset;
  }

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewportWidth = constraints.maxWidth;
        final double viewportHeight = constraints.maxHeight;

        final double scaledWidth = widget.canvasWidth * _scale;
        final double scaledHeight = widget.canvasHeight * _scale;

        final double centerX = max(0, (viewportWidth - scaledWidth) / 2);
        final double centerY = max(0, (viewportHeight - scaledHeight) / 2);

        return GestureDetector(
          onScaleStart: (final ScaleStartDetails details) {
            if (details.pointerCount == 2) {
              _lastFocalPoint = details.focalPoint;
              _lastScale = _scale;
              _panStartFocalPoint =
                  details.focalPoint; //Initialize PanStart on 2 finger
            }
          },
          onScaleUpdate: (final ScaleUpdateDetails details) {
            if (details.pointerCount == 2) {
              setState(
                () {
                  if (_lastFocalPoint != null && _panStartFocalPoint != null) {
                    final double scaleDelta =
                        (details.scale - _lastScale).abs();

                    if (scaleDelta > 0.3) {
                      // debugPrint('Scale by $scaleDelta');
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
                },
              );
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
