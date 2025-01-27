// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fpaint/files/file_jpeg.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/share_panel.dart';

/// Exports the current painter as a PNG image and triggers a download.
///
/// This function captures the current painter's image bytes and creates a PNG
/// file that is then downloaded to the user's device.
///
/// [context] The BuildContext to access the current AppModel.
Future<void> onExportAsPng(final BuildContext context) async {
  // Capture the image bytes
  final Uint8List imageBytes =
      await capturePainterToImageBytes(AppModel.get(context));

  // Create a Blob from the image bytes
  downloadBlob(imageBytes, 'image.png');
}

/// Exports the current painter as a JPG image and triggers a download.
///
/// This function captures the current painter's image bytes, converts it to JPG,
/// and creates a JPG file that is then downloaded to the user's device.
///
/// [context] The BuildContext to access the current AppModel.
Future<void> onExportAsJpeg(final BuildContext context) async {
  // Capture the image bytes
  final Uint8List imageBytes =
      await capturePainterToImageBytes(AppModel.get(context));

  // Convert the image bytes to JPG format
  final Uint8List outputBytes = await convertToJpg(imageBytes);

  // Create a Blob from the image bytes
  downloadBlob(outputBytes, 'image.jpg');
}

/// Exports the current painter as a TIF image and triggers a download.
///
/// This function captures the current painter's image bytes, converts it to TIF,
/// and creates a TIF file that is then downloaded to the user's device.
///
/// [context] The BuildContext to access the current AppModel.
Future<void> onExportAsTiff(final BuildContext context) async {
  // Capture the image bytes
  final Uint8List imageBytes =
      await capturePainterToImageBytes(AppModel.get(context));

  // Convert the image bytes to TIF format
  final Uint8List outputBytes = await convertToTif(imageBytes);

  // Create a Blob from the image bytes
  downloadBlob(outputBytes, 'image.tif');
}

/// Exports the current painter as an ORA file and triggers a download.
///
/// This function captures the current painter's image bytes, creates an ORA
/// archive, and then downloads the file to the user's device.
///
/// [context] The BuildContext to access the current AppModel.
Future<void> onExportAsOra(
  final BuildContext context,
) async {
  List<int> image = await createOraAchive(AppModel.get(context));
  downloadBlob(Uint8List.fromList(image), 'image.ora');
}

/// Downloads a file represented by the given image bytes and file name.
///
/// This function creates a Blob from the provided image bytes, generates an
/// object URL for the Blob, creates an anchor element for downloading the file,
/// triggers the download, and then revokes the object URL.
///
/// [image] The image bytes to be downloaded.
/// [fileName] The name of the file to be downloaded.
void downloadBlob(final Uint8List image, final String fileName) {
  // Create a Blob from the image bytes
  final blob = html.Blob([image]);

  // Generate an object URL for the Blob
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Create an anchor element for downloading the file
  final anchor = html.AnchorElement(href: url)
    ..target = 'blank' // Opens in a new tab if needed
    ..download = fileName; // Name of the downloaded file

  // Trigger the download
  anchor.click();

  // Revoke the object URL after the download
  html.Url.revokeObjectUrl(url);
}
