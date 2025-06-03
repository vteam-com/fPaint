import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

/// Handles the creation of a new file within the application.
///
/// This asynchronous function is triggered when the user opts to create a
/// new file. It performs necessary operations to initialize the new file
/// and integrates it into the application's context.
///
/// [context] The BuildContext of the widget that invokes this function.
Future<void> onFileNew(final BuildContext context) async {
  final AppProvider appProvider = AppProvider.of(context);

  if (appProvider.layers.hasChanged && await confirmDiscardCurrentWork(context) == false) {
    return;
  }

  // Dialog to get desired canvas size
  final bool offNewDocFromClipboard = await clipboardHasImage();

  if (context.mounted) {
    await showDialog<Size>(
      context: context,
      builder: (final BuildContext context) {
        final TextEditingController widthController = TextEditingController(text: '800');
        final TextEditingController heightController = TextEditingController(text: '800');

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
        if (context.mounted) {
          await openFileFromPath(
            context: context,
            layers: layers,
            path: path,
          );
        }
        shellProvider.loadedFileName = path;
      }
      layers.clearHasChanged();
    }
  } catch (e) {
    // Handle any errors that occur during file picking/loading
    debugPrint('Error opening file: $e');
  }
}

/// Opens a file from the specified file path.
///
/// This function takes a file path as input and performs the necessary
/// operations to open the file. It provides feedback when unsupported file types
/// are encountered.
///
/// Parameters:
/// - `layers`: The LayersProvider to load the file into
/// - `path`: A string representing the path to the file to be opened.
///
/// Returns:
/// - A `Future<bool>` that completes with true if the file was successfully opened,
///   or false if the file type is not supported.
Future<bool> openFileFromPath({
  required final BuildContext context,
  required final LayersProvider layers,
  required final String path,
}) async {
  if (!context.mounted) {
    return false;
  }

  final String extension = path.split('.').last.toLowerCase();

  if (extension == 'xcf') {
    // Show unsupported format message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('XCF format is not currently supported'),
        duration: Duration(seconds: 3),
      ),
    );

    return false;
  }

  if (isFileExtensionSupported(extension)) {
    try {
      if (extension == 'ora') {
        // File with support for layers
        await readImageFromFilePathOra(layers, path);
      } else {
        // PNG, JPG, WEBP
        await readImageFromFilePath(layers, path);
      }
      return true;
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
  } else {
    // Show unsupported format message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File format .$extension is not supported'),
        duration: const Duration(seconds: 3),
      ),
    );

    return false;
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

/// Checks if the given file extension is supported.
///
/// This function takes a file extension as input and determines whether
/// it is supported by the application.
///
/// [extension] The file extension to check (e.g., "jpg", "png").
///
/// Returns `true` if the file extension is supported, otherwise `false`.
bool isFileExtensionSupported(final String extension) {
  return supportedImageFileExtensions.contains(extension.toLowerCase());
}

/// Reads an image file asynchronously.
///
/// This function is responsible for handling the process of reading
/// an image file. It performs the necessary operations to load the
/// image data into memory for further processing or display.
///
/// Throws:
/// - An exception if the file cannot be read or if an error occurs
///   during the file reading process.
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

/// Reads an image from the specified file path.
///
/// This function asynchronously processes the file located at the given
/// file path and attempts to read it as an image. It can be used to load
/// image files for further processing or display.
///
/// Throws:
/// - An exception if the file cannot be read or is not a valid image.
///
/// Returns:
/// - A `Future` that completes when the image has been successfully read.
Future<void> readImageFromFilePath(
  final LayersProvider layers,
  final String path,
) async {
  await _readImageFile(layers, File(path).readAsBytes());
}

/// Reads an image file from a byte array.
///
/// This function processes the provided byte data to extract and handle
/// image information. It is typically used when the image data is already
/// available in memory as a byte array, such as when loading images from
/// a network or other non-file-based sources.
///
/// Returns a [Future] that completes when the image file has been
/// successfully read and processed.
Future<void> readImageFileFromBytes(
  final LayersProvider layers,
  final Uint8List bytes,
) async {
  // ignore: always_specify_types
  await _readImageFile(layers, Future.value(bytes));
}

/// Displays a confirmation dialog to the user asking if they want to discard
/// their current work.
///
/// This function is typically used when there are unsaved changes, and the user
/// attempts to navigate away or perform an action that would result in losing
/// their progress.
///
/// Returns a [Future] that resolves to `true` if the user confirms they want to
/// discard their work, or `false` if they cancel.
///
/// - Parameters:
///   - context: The [BuildContext] used to display the dialog.
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
