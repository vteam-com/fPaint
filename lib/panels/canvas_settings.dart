import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/nine_grid_selector.dart';

final TextEditingController widthController = TextEditingController();
final TextEditingController heightController = TextEditingController();
bool initOnce = false;

void showCanvasSettings(final BuildContext context) {
  initOnce = true;
  showModalBottomSheet(
    context: context,
    builder: (final BuildContext context) {
      AppModel appModel = AppModel.get(context, listen: true);
      if (initOnce) {
        widthController.text = appModel.canvasSize.width.toInt().toString();
        heightController.text = appModel.canvasSize.height.toInt().toString();
        initOnce = false;
      }

      double initialAspectRatio =
          appModel.canvasSize.width / appModel.canvasSize.height;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Canvas Size',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(
                height: 30,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                      onChanged: (value) {
                        if (appModel.canvasResizeLockAspectRatio) {
                          double width = double.tryParse(value) ??
                              double.tryParse(widthController.text)!;
                          double height = width / initialAspectRatio;
                          heightController.value =
                              TextEditingValue(text: height.toInt().toString());
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      appModel.canvasResizeLockAspectRatio
                          ? Icons.link
                          : Icons.link_off,
                    ),
                    onPressed: () {
                      appModel.canvasResizeLockAspectRatio =
                          !appModel.canvasResizeLockAspectRatio;
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
                      onChanged: (value) {
                        if (appModel.canvasResizeLockAspectRatio) {
                          double height = double.tryParse(value) ??
                              double.tryParse(heightController.text)!;
                          double width = height * initialAspectRatio;
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
                children: [
                  const Text('Content Alignment'),
                  NineGridSelector(
                    selectedPosition: appModel.canvasResizePosition,
                    onPositionSelected: (final int newPosition) {
                      appModel.canvasResizePosition = newPosition;
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
                      appModel.resizeCanvas(width.toInt(), height.toInt());
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
