import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_tiff.dart';
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
      // layers.clear(); // Removed from here

      if (kIsWeb) {
        final Uint8List bytes = result.files.single.bytes!;
        final String fileName = result.files.single.name; // Get filename for naming the layer
        final String extension = result.files.single.extension?.toLowerCase() ?? '';
        if (extension == 'ora') {
          // Assuming readOraFileFromBytes handles its own clearing and sizing or needs similar refactor
          await readOraFileFromBytes(layers, bytes);
        } else if (extension == 'tif' || extension == 'tiff') {
          // Assuming readTiffFileFromBytes handles its own clearing and sizing or needs similar refactor
          await readTiffFileFromBytes(layers, bytes);
        } else if (isFileExtensionSupported(extension)) {
          // Pass context and filename
          await readImageFileFromBytes(layers, bytes, context, imageName: fileName);
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
        content: Text('XCF files are not currently supported. Canvas will not be changed.'),
        duration: Duration(seconds: 3),
      ),
    );

    return false;
  }

  if (isFileExtensionSupported(extension)) {
    try {
      if (extension == 'ora') {
        // File with support for layers
        // Assuming readImageFromFilePathOra handles its own clearing and sizing or needs similar refactor
        await readImageFromFilePathOra(layers, path);
        return true; // Assuming success if no error
      } else if (extension == 'tif' || extension == 'tiff') {
        // Assuming readTiffFromFilePath handles its own clearing and sizing or needs similar refactor
        await readTiffFromFilePath(layers, path);
        return true; // Assuming success if no error
      } else {
        // PNG, JPG, WEBP
        // Pass context, extract filename for layer name
        final String fileName = path.split(Platform.pathSeparator).last;
        return await readImageFromFilePath(layers, path, context, imageName: fileName);
      }
    } catch (e) {
      // General error catch, readImageFromFilePath might have already shown a SnackBar for decode errors
      // ignore: use_build_context_synchronously
      if (context.mounted) { // Check context validity
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing file: ${e.toString()}'),
          ),
        );
      }
      return false;
    }
  } else {
    // Show unsupported format message
    // ignore: use_build_context_synchronously
    if (context.mounted) { // Check context validity
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File format .$extension is not supported'),
          duration: const Duration(seconds: 3),
        ),
      );
      }
      return false; // Return false regardless of context.mounted if format is not supported
    }
    // Removed duplicated else block
}

final List<String> supportedImageFileExtensions = <String>[
  'ora',
  'png',
  // 'psd',
  'tif',
  'tiff',
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
/// Decodes image bytes, clears layers, sets canvas size, and adds the image.
/// Handles decoding errors and shows a SnackBar.
Future<bool> _decodeAndApplyImage(
  final LayersProvider layers,
  final Uint8List imageBytes,
  final BuildContext context, {
  final String imageName = 'Loaded Image',
}) async {
  try {
    final ui.Image image = await decodeImageFromList(imageBytes);

    layers.clear(); // Clear layers only after successful decoding
    layers.size = Size(image.width.toDouble(), image.height.toDouble());
    layers.addTop(name: imageName); // Add a new layer with the image name
    layers.selectedLayer.addImage(imageToAdd: image);
    layers.update(); // Notify listeners of all changes

    return true; // Success
  } catch (e) {
    // ignore: use_build_context_synchronously
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load image: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return false; // Failure
  }
}

/// Reads an image from the specified file path.
Future<bool> readImageFromFilePath(
  final LayersProvider layers,
  final String path,
  final BuildContext context, {
  final String imageName = 'Loaded Image',
}) async {
  try {
    final Uint8List fileBytes = await File(path).readAsBytes();
    return await _decodeAndApplyImage(layers, fileBytes, context, imageName: imageName);
  } catch (e) {
    // ignore: use_build_context_synchronously
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reading file: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return false;
  }
}

/// Reads an image file from a byte array.
Future<bool> readImageFileFromBytes(
  final LayersProvider layers,
  final Uint8List bytes,
  final BuildContext context, {
  final String imageName = 'Loaded Image',
}) async {
  return await _decodeAndApplyImage(layers, bytes, context, imageName: imageName);
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
