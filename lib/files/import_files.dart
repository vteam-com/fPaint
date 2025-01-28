import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/models/app_model.dart';

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
  final AppModel appModel = AppModel.get(context);

  try {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
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
        if (result.files.single.extension == 'ora') {
          await readOraFile(appModel, path);
        } else if (isFileExtensionSupported(
          result.files.single.extension ?? '',
        )) {
          await readImageFilePath(appModel, path);
        }
      }
    }
  } catch (e) {
    // Handle any errors that occur during file picking/loading
    debugPrint('Error opening file: $e');
  }
}

bool isFileExtensionSupported(String extension) {
  List<String> supportedExtensions = [
    'ora',
    'png',
    'psd',
    'tif',
    'tiff',
    'webp',
    'jpg',
    'jpeg',
  ];
  return supportedExtensions.contains(extension.toLowerCase());
}

Future<void> _readImageFile(
  AppModel appModel,
  Future<Uint8List> bytesFuture,
) async {
  final image = await decodeImageFromList(await bytesFuture);
  appModel.layers.clear();
  appModel.addLayerTop();
  appModel.canvasSize = Size(image.width.toDouble(), image.height.toDouble());
  appModel.selectedLayer.addImage(image);
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
