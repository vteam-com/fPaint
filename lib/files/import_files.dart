import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/confirm_discard_dialog.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';
import 'package:logging/logging.dart';

const String _defaultCanvasDimension = '800';
const String _fileExtensionOra = 'ora';
const String _fileExtensionTif = 'tif';
const String _fileExtensionTiff = 'tiff';
const String _fileExtensionPng = 'png';
const String _fileExtensionWebp = 'webp';
const String _fileExtensionJpg = 'jpg';
const String _fileExtensionJpeg = 'jpeg';
const String _loadedImageDefaultName = 'Loaded Image';

final Logger _log = Logger(logNameImportFiles);

/// Handles the creation of a new file within the application.
///
/// This asynchronous function is triggered when the user opts to create a
/// new file. It performs necessary operations to initialize the new file
/// and integrates it into the application's context.
///
/// [context] The BuildContext of the widget that invokes this function.
Future<void> onFileNew(final BuildContext context) async {
  final AppProvider appProvider = AppProvider.of(context);
  final AppLocalizations l10n = context.l10n;

  if (appProvider.layers.hasChanged && await confirmDiscardCurrentWork(context) == false) {
    return;
  }

  // Dialog to get desired canvas size
  final bool offNewDocFromClipboard = await clipboardHasImage();

  if (context.mounted) {
    await showAppDialog<Size>(
      context: context,
      builder: (final BuildContext context) {
        final TextEditingController widthController = TextEditingController(text: _defaultCanvasDimension);
        final TextEditingController heightController = TextEditingController(text: _defaultCanvasDimension);

        return AppDialog(
          title: Text(l10n.newCanvasSize),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xxl,
            children: <Widget>[
              AppTextField(
                controller: widthController,
                keyboardType: TextInputType.number,
                hintText: l10n.width,
              ),
              AppTextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                hintText: l10n.height,
              ),
            ],
          ),
          actions: <Widget>[
            if (offNewDocFromClipboard)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xxl),
                child: AppElevatedButton(
                  onPressed: () {
                    // Handle creating new document from clipboard image
                    appProvider.newDocumentFromClipboardImage();
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.newFromClipboard),
                ),
              ),
            AppTextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: Text(l10n.cancel),
            ),
            AppTextButton(
              onPressed: () {
                final double? width = double.tryParse(widthController.text);
                final double? height = double.tryParse(heightController.text);
                if (width != null && height != null) {
                  appProvider.canvasClear(Size(width, height));
                  Navigator.of(context).pop();
                } else {
                  // Show error message if input is invalid
                  context.showSnackBarMessage(l10n.invalidSize);
                }
              },
              child: Text(l10n.create),
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
  final AppLocalizations l10n = context.l10n;

  if (layers.hasChanged && await confirmDiscardCurrentWork(context) == false) {
    return;
  }

  try {
    final FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: l10n.fpaintLoadImage,
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
        if (extension == _fileExtensionOra) {
          // Assuming readOraFileFromBytes handles its own clearing and sizing or needs similar refactor
          await readOraFileFromBytes(layers, bytes);
        } else if (extension == _fileExtensionTif || extension == _fileExtensionTiff) {
          // Assuming readTiffFileFromBytes handles its own clearing and sizing or needs similar refactor
          await readTiffFileFromBytes(layers, bytes);
        } else if (isFileExtensionSupported(extension)) {
          // Pass context and filename
          // ignore: use_build_context_synchronously
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
    _log.severe('Error opening file', e);
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

  if (isFileExtensionSupported(extension)) {
    try {
      if (extension == _fileExtensionOra) {
        await readImageFromFilePathOra(layers, path);
        return true;
      } else if (extension == _fileExtensionTif || extension == _fileExtensionTiff) {
        await readTiffFromFilePath(layers, path);
        return true;
      } else {
        final String fileName = path.split(Platform.pathSeparator).last;
        return await readImageFromFilePath(layers, path, context, imageName: fileName);
      }
    } catch (e) {
      // General error catch, readImageFromFilePath might have already shown a SnackBar for decode errors
      // ignore: use_build_context_synchronously
      if (context.mounted) {
        context.showSnackBarMessage(
          context.l10n.errorProcessingFile(e.toString()),
        );
      }
      return false;
    }
  } else {
    // Show unsupported format message
    // ignore: use_build_context_synchronously
    if (context.mounted) {
      context.showSnackBarMessage(
        context.l10n.fileFormatNotSupported(extension),
        duration: const Duration(seconds: AppMath.triple),
      );
    }
    return false; // Return false regardless of context.mounted if format is not supported
  }
  // Removed duplicated else block
}

final List<String> supportedImageFileExtensions = <String>[
  _fileExtensionOra,
  _fileExtensionPng,
  // 'psd',
  _fileExtensionTif,
  _fileExtensionTiff,
  _fileExtensionWebp,
  _fileExtensionJpg,
  _fileExtensionJpeg,
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
  final String imageName = _loadedImageDefaultName,
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
      context.showSnackBarMessage(
        context.l10n.failedToLoadImage(e.toString()),
        duration: const Duration(seconds: AppMath.triple),
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
  final String imageName = _loadedImageDefaultName,
}) async {
  try {
    final Uint8List fileBytes = await File(path).readAsBytes();
    // ignore: use_build_context_synchronously
    return await _decodeAndApplyImage(layers, fileBytes, context, imageName: imageName);
  } catch (e) {
    // ignore: use_build_context_synchronously
    if (context.mounted) {
      context.showSnackBarMessage(
        context.l10n.errorReadingFile(e.toString()),
        duration: const Duration(seconds: AppMath.triple),
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
  final String imageName = _loadedImageDefaultName,
}) async {
  return await _decodeAndApplyImage(layers, bytes, context, imageName: imageName);
}

/// The result chosen by the user when dropping a file onto a canvas that
/// already contains content.
enum DropFileAction {
  /// Open the file, replacing the current content.
  open,

  /// Add the file as a new layer on top of the existing content.
  addLayer,
}

/// Handles a file dropped onto the canvas from the desktop.
///
/// When the canvas has no meaningful content the file is opened directly.
/// Otherwise a dialog asks the user whether to open the file (replacing the
/// current content) or to add it as a new layer.
Future<void> onFileDropped({
  required final BuildContext context,
  required final String path,
}) async {
  final LayersProvider layers = LayersProvider.of(context);
  final ShellProvider shellProvider = ShellProvider.of(context);

  final String extension = path.split('.').last.toLowerCase();
  if (!isFileExtensionSupported(extension)) {
    if (context.mounted) {
      context.showSnackBarMessage(
        context.l10n.fileFormatNotSupported(extension),
        duration: const Duration(seconds: AppMath.triple),
      );
    }
    return;
  }

  final bool canvasHasContent = layers.list.any(
    (final LayerProvider layer) => layer.actionStack.isNotEmpty,
  );

  if (canvasHasContent) {
    final DropFileAction? action = await showAppDialog<DropFileAction>(
      context: context,
      builder: (final BuildContext dialogContext) {
        final AppLocalizations l10n = dialogContext.l10n;
        return AppDialog(
          title: Text(l10n.dropFileTitle),
          content: Text(l10n.dropFilePrompt),
          actions: <Widget>[
            AppTextButton(
              onPressed: () => Navigator.pop(dialogContext, DropFileAction.addLayer),
              child: Text(l10n.dropFileAddLayer),
            ),
            AppTextButton(
              onPressed: () => Navigator.pop(dialogContext, DropFileAction.open),
              child: Text(l10n.dropFileOpen),
            ),
          ],
        );
      },
    );

    if (action == null || !context.mounted) {
      return;
    }

    if (action == DropFileAction.addLayer) {
      await _addDroppedFileAsLayer(
        context: context,
        layers: layers,
        path: path,
      );
      return;
    }
  }

  // Open the file, replacing the current content.
  if (context.mounted) {
    await openFileFromPath(context: context, layers: layers, path: path);
    shellProvider.loadedFileName = path;
    layers.clearHasChanged();
  }
}

/// Decodes the image at [path] and adds it as a new layer on top of the
/// current layer stack.
Future<void> _addDroppedFileAsLayer({
  required final BuildContext context,
  required final LayersProvider layers,
  required final String path,
}) async {
  final String fileName = path.split(Platform.pathSeparator).last;

  try {
    final Uint8List fileBytes = await File(path).readAsBytes();
    final ui.Image image = await decodeImageFromList(fileBytes);

    layers.addTop(name: fileName);
    layers.selectedLayer.addImage(imageToAdd: image);
    layers.update();
  } catch (e) {
    if (context.mounted) {
      context.showSnackBarMessage(
        context.l10n.failedToLoadImage(e.toString()),
        duration: const Duration(seconds: AppMath.triple),
      );
    }
  }
}
