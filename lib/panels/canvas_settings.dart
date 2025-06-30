import 'package:flutter/material.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/nine_grid_selector.dart';

/// TextEditingController for the width input field.
final TextEditingController widthController = TextEditingController();

/// TextEditingController for the height input field.
final TextEditingController heightController = TextEditingController();

/// Flag to ensure initialization logic is executed only once.
bool initOnce = false;

/// Displays a modal bottom sheet for adjusting canvas settings.
///
/// This function presents a user interface for modifying the canvas size,
/// including width and height inputs, aspect ratio locking, and content alignment
/// options. It allows users to resize the canvas while maintaining the content's
/// positioning within the new dimensions.
///
/// The [context] parameter is the [BuildContext] used to display the modal.
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

      // Use a mutable variable for initialAspectRatio, local to the builder
      double initialAspectRatio = (layers.size.height != 0) ? (layers.size.width / layers.size.height) : 1.0;

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
                      onChanged: (final String value) {
                        if (layers.canvasResizeLockAspectRatio) {
                          if (initialAspectRatio == 0) {
                            return; // Avoid division by zero
                          }
                          final double currentParsedWidth =
                              double.tryParse(value) ?? double.tryParse(widthController.text) ?? layers.size.width;
                          final double newHeight = currentParsedWidth / initialAspectRatio;
                          heightController.value = TextEditingValue(text: newHeight.toInt().toString());
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      layers.canvasResizeLockAspectRatio ? Icons.link : Icons.link_off,
                    ),
                    onPressed: () {
                      final bool newLockState = !layers.canvasResizeLockAspectRatio;
                      if (newLockState) {
                        // Attempt to recalculate aspect ratio from current text field values when locking
                        final double? currentWidthFromField = double.tryParse(widthController.text);
                        final double? currentHeightFromField = double.tryParse(heightController.text);
                        if (currentWidthFromField != null &&
                            currentHeightFromField != null &&
                            currentWidthFromField > 0 &&
                            currentHeightFromField > 0) {
                          initialAspectRatio = currentWidthFromField / currentHeightFromField;
                        }
                        // If parsing fails or values are non-positive, initialAspectRatio remains as it was.
                      }
                      layers.canvasResizeLockAspectRatio = newLockState;
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
                      onChanged: (final String value) {
                        if (layers.canvasResizeLockAspectRatio) {
                          final double currentParsedHeight =
                              double.tryParse(value) ?? double.tryParse(heightController.text) ?? layers.size.height;
                          final double newWidth = currentParsedHeight * initialAspectRatio;
                          widthController.text = newWidth.toInt().toString();
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
                    onPositionSelected: (final CanvasResizePosition newPosition) {
                      layers.canvasResizePosition = newPosition;
                    },
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    final double width = double.tryParse(widthController.text) ?? -1;
                    final double height = double.tryParse(heightController.text) ?? -1;
                    if (width == -1 || height == -1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid image size: Dimensions must be numbers.'),
                        ),
                      );
                    } else if (width <= 0 || height <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Canvas dimensions must be positive.'),
                        ),
                      );
                    } else {
                      layers.canvasResize(
                        width.toInt(),
                        height.toInt(),
                        layers.canvasResizePosition,
                      );
                      AppProvider.of(context, listen: false).canvasFitToContainer(
                        containerWidth: MediaQuery.of(context).size.width,
                        containerHeight: MediaQuery.of(context).size.height,
                      );
                      AppProvider.of(context, listen: false).update(); // <-- Add this line
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
