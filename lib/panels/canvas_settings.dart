import 'package:flutter/material.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/nine_grid_selector.dart';

final TextEditingController widthController = TextEditingController();
final TextEditingController heightController = TextEditingController();
bool initOnce = false;

void showCanvasSettings(final BuildContext context) {
  initOnce = true;
  showModalBottomSheet<dynamic>(
    context: context,
    builder: (final BuildContext context) {
      final LayersProvider layers = LayersProvider.of(context, listen: true);
      if (initOnce) {
        widthController.text = layers.size.width.toInt().toString();
        heightController.text = layers.size.height.toInt().toString();
        initOnce = false;
      }

      final double initialAspectRatio = layers.size.width / layers.size.height;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Canvas Size',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(
                height: 30,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 150,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Width',
                        suffixText: 'px',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: widthController,
                      onChanged: (String value) {
                        if (layers.canvasResizeLockAspectRatio) {
                          final double width = double.tryParse(value) ??
                              double.tryParse(widthController.text)!;
                          final double height = width / initialAspectRatio;
                          heightController.value =
                              TextEditingValue(text: height.toInt().toString());
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      layers.canvasResizeLockAspectRatio
                          ? Icons.link
                          : Icons.link_off,
                    ),
                    onPressed: () {
                      layers.canvasResizeLockAspectRatio =
                          !layers.canvasResizeLockAspectRatio;
                    },
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        suffixText: 'px',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: heightController,
                      onChanged: (String value) {
                        if (layers.canvasResizeLockAspectRatio) {
                          final double height = double.tryParse(value) ??
                              double.tryParse(heightController.text)!;
                          final double width = height * initialAspectRatio;
                          widthController.text = width.toInt().toString();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 30,
              ),
              Column(
                spacing: 10,
                children: <Widget>[
                  const Text('Content Alignment'),
                  NineGridSelector(
                    selectedPosition: layers.canvasResizePosition,
                    onPositionSelected: (final int newPosition) {
                      layers.canvasResizePosition = newPosition;
                    },
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    final double width =
                        double.tryParse(widthController.text) ?? -1;
                    final double height =
                        double.tryParse(heightController.text) ?? -1;
                    if (width == -1 || height == -1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid image size'),
                        ),
                      );
                    } else {
                      layers.canvasResize(width.toInt(), height.toInt());
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
