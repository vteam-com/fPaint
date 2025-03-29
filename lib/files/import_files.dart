import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

Future<void> onFileNew(final BuildContext context) async {
  final AppProvider appProvider = AppProvider.of(context);

  if (appProvider.layers.hasChanged &&
      await confirmDiscardCurrentWork(context) == false) {
    return;
  }

  // Dialog to get desired canvas size
  final bool offNewDocFromClipboard = await clipboardHasImage();

  if (context.mounted) {
    await showDialog<Size>(
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
            if (offNewDocFromClipboard)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: ElevatedButton(
                  onPressed: () {
                    // Handle creating new document from clipboard image
                    appProvider.newDocumentFromClipboardImage();
                    Navigator.of(context).pop();
                  },
                  child: const Text('New from Clipboard'),
                ),
              ),
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
                  appProvider.canvasClear(Size(width, height));
                  Navigator.of(context).pop();
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
  final ShellProvider shellProvider = ShellProvider.of(context);
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
          await readOraFileFromBytes(layers, bytes);
        } else if (isFileExtensionSupported(
          result.files.single.extension ?? '',
        )) {
          await readImageFileFromBytes(layers, bytes);
        }
      } else {
        final String path = result.files.single.path!;
        shellProvider.loadedFileName = path;
        await openFileFromPath(layers, path);
        shellProvider.loadedFileName = path;
      }
      layers.clearHasChanged();
    }
  } catch (e) {
    // Handle any errors that occur during file picking/loading
    debugPrint('Error opening file: $e');
  }
}

Future<void> openFileFromPath(
  final LayersProvider layers,
  final String path,
) async {
  final String extension = path.split('.').last.toLowerCase();

  if (extension == 'xcf') {
    // TODO - No Currently supported
    return;
  }

  if (isFileExtensionSupported(extension)) {
    if (extension == 'ora') {
      // File with support for layers
      await readImageFromFilePathOra(layers, path);
    } else {
      // PNG, JPG, WEBP
      await readImageFromFilePath(layers, path);
    }
  }
}

final List<String> supportedImageFileExtensions = <String>[
  'ora',
  'png',
  // 'psd',
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

Future<void> readImageFromFilePath(
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
