import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

Future<void> onFileNew(final BuildContext context) async {
  final AppProvider appModel = AppProvider.of(context);

  if (appModel.layers.hasChanged &&
      await confirmDiscardCurrentWork(context) == false) {
    return;
  }

  // Dialog to get desired canvas size
  if (context.mounted) {
    final Size? canvasSize = await showDialog<Size>(
      context: context,
      builder: (final BuildContext context) {
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
      appModel.canvasClear(canvasSize);
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
  final ShellProvider shellModel = ShellProvider.of(context);
  final LayersProvider layers = LayersProvider.of(context);

  if (layers.hasChanged && await confirmDiscardCurrentWork(context) == false) {
    return;
  }

  try {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'fPaint Load Image',
      // type: FileType.custom,
      // allowedExtensions: supportedImageFileExtensions,
      allowMultiple: false,
      withData: true,
      lockParentWindow: true,
    );

    if (result != null) {
      layers.clear();

      if (kIsWeb) {
        final Uint8List bytes = result.files.single.bytes!;
        if (result.files.single.extension == 'ora') {
          await readOraFileFromBytes(shellModel, layers, bytes);
        } else if (isFileExtensionSupported(
          result.files.single.extension ?? '',
        )) {
          await readImageFileFromBytes(layers, bytes);
        }
      } else {
        final String path = result.files.single.path!;
        shellModel.loadedFileName = path;
        if (result.files.single.extension == 'xcf') {
          // TODO
        } else if (result.files.single.extension == 'ora') {
          await readOraFile(shellModel, layers, path);
        } else if (isFileExtensionSupported(
          result.files.single.extension ?? '',
        )) {
          await readImageFilePath(layers, path);
        }
      }
      layers.clearHasChanged();
    }
  } catch (e) {
    // Handle any errors that occur during file picking/loading
    debugPrint('Error opening file: $e');
  }
}

final List<String> supportedImageFileExtensions = <String>[
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

bool isFileExtensionSupported(final String extension) {
  return supportedImageFileExtensions.contains(extension.toLowerCase());
}

Future<void> _readImageFile(
  final LayersProvider layers,
  final Future<Uint8List> bytesFuture,
) async {
  final ui.Image image = await decodeImageFromList(await bytesFuture);
  layers.clear();
  layers.addTop();
  layers.size = Size(image.width.toDouble(), image.height.toDouble());
  layers.selectedLayer.addImage(imageToAdd: image);
}

Future<void> readImageFilePath(
  final LayersProvider layers,
  final String path,
) async {
  await _readImageFile(layers, File(path).readAsBytes());
}

Future<void> readImageFileFromBytes(
  final LayersProvider layers,
  final Uint8List bytes,
) async {
  // ignore: always_specify_types
  await _readImageFile(layers, Future.value(bytes));
}

Future<bool> confirmDiscardCurrentWork(final BuildContext context) async {
  final bool? discardCurrentFile = await showDialog<bool>(
    context: context,
    builder: (final BuildContext context) {
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
