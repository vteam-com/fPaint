import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/transparent_background.dart';
import 'package:fpaint/widgets/truncated_text.dart';

class LayerSelector extends StatelessWidget {
  const LayerSelector({
    super.key,
    required this.context,
    required this.layer,
    required this.minimal,
    required this.showDelete,
  });

  final BuildContext context;
  final Layer layer;
  final bool showDelete;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.get(context);
    return Container(
      margin: EdgeInsets.all(minimal ? 2 : 4),
      padding: EdgeInsets.all(minimal ? 2 : 8),
      decoration: BoxDecoration(
        color: minimal ? (layer.isVisible ? null : Colors.grey) : null,
        border: Border.all(
          color: layer.isSelected ? Colors.blue : Colors.grey.shade300,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: minimal
          ? Column(
              children: [
                TruncatedTextWidget(text: layer.name, maxLength: 10),
                LayerThumbnail(layer: layer),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(layer.name),
                ),
                Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: LayerThumbnail(layer: layer),
                ),
                // SizedBox(
                //   height: 60,
                //   child: OpacitySlider(
                //     layer: layer,
                //   ),
                // ),
                SizedBox(
                  height: 60,
                  width: 60,
                  child: HorizontalValueAdjuster(
                    minValue: 0.0,
                    maxValue: 100.0,
                    initialValue: layer.opacity,
                    onSlideStart: () {
                      // appModel.update();
                    },
                    onChanged: (value) => layer.opacity = value,
                    onChangeEnd: (value) {
                      layer.opacity = value;
                      appModel.update();
                    },
                    onSlideEnd: () => appModel.update(),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    layer.isVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => appModel.toggleLayerVisibility(layer),
                ),
                if (showDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => appModel.removeLayer(layer),
                  ),
              ],
            ),
    );
  }
}

class LayerThumbnail extends StatelessWidget {
  const LayerThumbnail({
    super.key,
    required this.layer,
  });

  final Layer layer;

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.get(context);
    return FutureBuilder<ui.Image>(
      future: layer.getThumbnail(appModel.canvasSize),
      builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return SizedBox(
            width: 50,
            height: 50,
            child: snapshot.data == null
                ? const SizedBox(
                    width: 50,
                    height: 50,
                    child: TransparentPaper(patternSize: 4),
                  )
                : CustomPaint(
                    painter: ImagePainter(snapshot.data!),
                  ),
          );
        } else if (snapshot.hasError) {
          return Container(
            width: 50,
            height: 50,
            color: Colors.red,
            child: const Center(
              child: Icon(Icons.error, color: Colors.white),
            ),
          );
        }
        return const SizedBox(
          width: 50,
          height: 50,
        );
      },
    );
  }
}

class ImagePainter extends CustomPainter {
  ImagePainter(this.image);
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Calculate the scale factors to fit the image into the destination rectangle
    final double scaleX = size.width / image.width;
    final double scaleY = size.height / image.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate the dimensions of the scaled image
    final double scaledWidth = image.width * scale;
    final double scaledHeight = image.height * scale;

    // Center the image within the destination rectangle
    final double dx = (size.width - scaledWidth) / 2;
    final double dy = (size.height - scaledHeight) / 2;

    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);

    // Draw the image
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OpacitySlider extends StatefulWidget {
  const OpacitySlider({
    super.key,
    required this.layer,
  });

  final Layer layer;

  @override
  OpacitySliderState createState() => OpacitySliderState();
}

class OpacitySliderState extends State<OpacitySlider> {
  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: -1,
      child: Slider(
        value: widget.layer.opacity,
        min: 0.0,
        max: 1.0,
        onChanged: (final double value) {
          setState(() {
            widget.layer.opacity = value;
          });
        },
      ),
    );
  }
}

class HorizontalValueAdjuster extends StatefulWidget {
  const HorizontalValueAdjuster({
    super.key,
    this.minValue = 0.0,
    this.maxValue = 100.0,
    this.initialValue = 50.0,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onSlideStart,
    required this.onSlideEnd,
  });
  final double minValue;
  final double maxValue;
  final double initialValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onSlideStart;
  final VoidCallback onSlideEnd;

  @override
  State<HorizontalValueAdjuster> createState() =>
      _HorizontalValueAdjusterState();
}

class _HorizontalValueAdjusterState extends State<HorizontalValueAdjuster> {
  late double currentValue;
  double? initialTouchValue;

  @override
  void initState() {
    super.initState();
    currentValue = widget.initialValue.clamp(widget.minValue, widget.maxValue);
  }

  void _adjustValue(double delta) {
    setState(() {
      currentValue =
          (currentValue + delta).clamp(widget.minValue, widget.maxValue);
    });
    widget.onChanged(currentValue);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _HorizontalDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_HorizontalDragRecognizer>(
          () => _HorizontalDragRecognizer(),
          (instance) {
            instance
              ..onStart = (_) {
                widget.onSlideStart(); // Pause reordering.
              }
              ..onUpdate = (details) {
                _adjustValue(
                  details.primaryDelta! * 0.2,
                ); // Adjust sensitivity.
              }
              ..onEnd = (_) {
                widget.onSlideEnd(); // Resume reordering.
                widget.onChangeEnd(currentValue);
              };
          },
        ),
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: Text(
            currentValue.toStringAsFixed(0),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _HorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    // Accept gesture even if it's competing with other gestures.
    acceptGesture(pointer);
  }
}
