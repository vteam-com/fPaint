import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_jpeg.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/share_panel.dart';

/// Exports the current painter content as a PNG image file.
///
/// This function captures the current state of the painter as image bytes
/// and prompts the user to save the image as a PNG file. The user is presented
/// with a file save dialog to choose the location and name of the file.
///
/// The function performs the following steps:
/// 1. Retrieves the current `AppModel` from the provided `BuildContext`.
/// 2. Opens a file save dialog for the user to specify the file path and name.
/// 3. Captures the painter content as image bytes.
/// 4. Writes the image bytes to the specified file path.
///
/// Parameters:
/// - `context`: The `BuildContext` used to retrieve the `AppModel`.
///
/// Returns:
/// - A `Future<void>` that completes when the image has been successfully saved.
Future<void> onExportAsPng(final BuildContext context) async {
  final AppModel appModel = AppModel.get(context);
  final String? filePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save image',
    fileName: 'image.png',
    allowedExtensions: ['png'],
    type: FileType.custom,
  );
  if (filePath != null) {
    // Capture the image bytes
    final Uint8List bytes = await capturePainterToImageBytes(appModel);
    await File(filePath).writeAsBytes(bytes);
  }
}

/// Exports the current painter content as a JPG image file.
///
/// This function captures the current state of the painter as image bytes
/// and prompts the user to save the image as a JPG file. The user is presented
/// with a file save dialog to choose the location and name of the file.
///
/// The function performs the following steps:
/// 1. Retrieves the current `AppModel` from the provided `BuildContext`.
/// 2. Opens a file save dialog for the user to specify the file path and name.
/// 3. Captures the painter content as image bytes.
/// 4. Writes the image bytes to the specified file path.
///
/// Parameters:
/// - `context`: The `BuildContext` used to retrieve the `AppModel`.
///
/// Returns:
/// - A `Future<void>` that completes when the image has been successfully saved.
Future<void> onExportAsJpeg(final BuildContext context) async {
  final AppModel appModel = AppModel.get(context);

  final String? filePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save image',
    fileName: 'image.jpg',
    allowedExtensions: ['jpg', 'jpeg'],
    type: FileType.custom,
  );
  if (filePath != null) {
    // Capture the image bytes
    final Uint8List imageBytes = await capturePainterToImageBytes(appModel);

    // Convert the image bytes to JPG format
    final Uint8List outputBytes = await convertToJpg(imageBytes);
    await File(filePath).writeAsBytes(outputBytes);
  }
}

/// Exports the current project as an ORA (OpenRaster) file.
///
/// This function handles the export process, converting the current project
/// into an ORA file format, which is a standard format for layered images.
///
/// The function is asynchronous and returns a [Future] that completes when
/// the export process is finished.
///
/// Throws an [Exception] if the export process fails.
Future<void> onExportAsOra(
  final BuildContext context,
) async {
  final AppModel appModel = AppModel.get(context);
  final String? filePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save image',
    fileName: 'image.ora',
    allowedExtensions: ['ora'],
    type: FileType.custom,
  );
  if (filePath != null) {
    final List<int> encodedData = await createOraAchive(appModel);
    await File(filePath).writeAsBytes(encodedData);
  }
}
