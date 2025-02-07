import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/models/app_model.dart';

Future<void> onFileNew(final BuildContext context) async {
  final AppModel appModel = AppModel.of(context);

  if (appModel.layers.hasChanged &&
      await confirmDiscardCurrentWork(context) == false) {
    return;
  }

  // Dialog to get desired canvas size
  if (context.mounted) {
    final Size? canvasSize = await showDialog<Size>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController widthController =
            TextEditingController(text: '800');
        final TextEditingController heightController =
            TextEditingController(text: '800');

        return AlertDialog(
          title: const Text('New Canvas Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 20,
            children: <Widget>[
              TextField(
                controller: widthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Width'),
              ),
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Height'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final double? width = double.tryParse(widthController.text);
                final double? height = double.tryParse(heightController.text);
                if (width != null && height != null) {
                  Navigator.of(context).pop(Size(width, height));
                } else {
                  // Show error message if input is invalid
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid size')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (canvasSize != null) {
      appModel.layers.clear();
      appModel.canvas.canvasSize = canvasSize;
      appModel.addLayerTop();
    }
  }
}

/// Opens a file and performs necessary operations.
///
/// This function is triggered when a file is opened in the application.
/// It performs asynchronous operations to handle the file appropriately.
///
/// Parameters:
/// - `context`: The `BuildContext` of the current widget tree.
///
/// Returns:
/// - A `Future<void>` indicating the completion of the file open operation.
Future<void> onFileOpen(final BuildContext context) async {
  final AppModel appModel = AppModel.of(context);

  if (appModel.layers.hasChanged &&
      await confirmDiscardCurrentWork(context) == false) {
    return;
  }

  try {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'fPaint Load Image',
      type: FileType.custom,
      allowedExtensions: supportedImageFileExtensions,
      allowMultiple: false,
      withData: true,
      lockParentWindow: true,
    );

    if (result != null) {
      appModel.layers.clear();

      if (kIsWeb) {
        final Uint8List bytes = result.files.single.bytes!;
        if (result.files.single.extension == 'ora') {
          await readOraFileFromBytes(appModel, bytes);
        } else if (isFileExtensionSupported(
          result.files.single.extension ?? '',
        )) {
          await readImageFileFromBytes(appModel, bytes);
        }
      } else {
        final path = result.files.single.path!;
        appModel.loadedFileName = path;
        if (result.files.single.extension == 'xcf') {
          // TODO
        } else if (result.files.single.extension == 'ora') {
          await readOraFile(appModel, path);
        } else if (isFileExtensionSupported(
          result.files.single.extension ?? '',
        )) {
          await readImageFilePath(appModel, path);
        }
      }
      appModel.layers.clearHasChanged();
    }
  } catch (e) {
    // Handle any errors that occur during file picking/loading
    debugPrint('Error opening file: $e');
  }
}

final List<String> supportedImageFileExtensions = [
  'ora',
  'png',
  'psd',
  // 'tif',
  // 'tiff',
  'webp',
  'jpg',
  'jpeg',
  // 'xcf',
];

bool isFileExtensionSupported(String extension) {
  return supportedImageFileExtensions.contains(extension.toLowerCase());
}

Future<void> _readImageFile(
  AppModel appModel,
  Future<Uint8List> bytesFuture,
) async {
  final image = await decodeImageFromList(await bytesFuture);
  appModel.layers.clear();
  appModel.addLayerTop();
  appModel.canvas.canvasSize =
      Size(image.width.toDouble(), image.height.toDouble());
  appModel.selectedLayer.addImage(imageToAdd: image);
}

Future<void> readImageFilePath(
  AppModel appModel,
  String path,
) async {
  await _readImageFile(appModel, File(path).readAsBytes());
}

Future<void> readImageFileFromBytes(
  AppModel appModel,
  Uint8List bytes,
) async {
  await _readImageFile(appModel, Future.value(bytes));
}

Future<bool> confirmDiscardCurrentWork(final BuildContext context) async {
  final bool? discardCurrentFile = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Discard current document?'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('No'),
          ),
        ],
      );
    },
  );

  return discardCurrentFile == true;
}
