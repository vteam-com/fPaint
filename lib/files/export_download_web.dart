// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop'; // For JS interop utilities
import 'dart:typed_data';

import 'package:fpaint/files/file_jpeg.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/panels/share_panel.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:web/web.dart' as web; // Add

/// Exports the current painter as a PNG image and triggers a download.
///
/// This function captures the current painter's image bytes and creates a PNG
/// file that is then downloaded to the user's device.
///
/// [context] The BuildContext to access the current AppModel.
Future<void> onExportAsPng(
  final LayersProvider layers, [
  final String fileName = 'image.png',
]) async {
  await saveAsPng(layers, fileName);
}

Future<void> saveAsPng(
  final LayersProvider layers,
  final String filePath,
) async {
  final Uint8List imageBytes = await capturePainterToImageBytes(layers);

  // Create a Blob from the image bytes
  downloadBlob(imageBytes, filePath);
}

/// Exports the current painter as a JPG image and triggers a download.
///
/// This function captures the current painter's image bytes, converts it to JPG,
/// and creates a JPG file that is then downloaded to the user's device.
///
/// [context] The BuildContext to access the current AppModel.
Future<void> onExportAsJpeg(
  final LayersProvider layers, [
  final String fileName = 'image.jpg',
]) async {
  await saveAsJpeg(layers, fileName);
}

Future<void> saveAsJpeg(
  final LayersProvider layers,
  final String filePath,
) async {
  final Uint8List imageBytes = await capturePainterToImageBytes(layers);

  // Convert the image bytes to JPG format
  final Uint8List outputBytes = await convertToJpg(imageBytes);

  // Create a Blob from the image bytes
  downloadBlob(outputBytes, filePath);
}

/// Exports the current painter as an ORA file and triggers a download.
///
/// This function captures the current painter's image bytes, creates an ORA
/// archive, and then downloads the file to the user's device.
///
/// [context] The BuildContext to access the current AppModel.
Future<void> onExportAsOra(
  final LayersProvider layers, [
  final String fileName = 'image.ora',
]) async {
  await saveAsOra(layers, fileName);
}

Future<void> saveAsOra(
  final LayersProvider layers,
  final String filePath,
) async {
  final List<int> image = await createOraAchive(layers);
  // Create a Blob from the image bytes
  downloadBlob(Uint8List.fromList(image), filePath);
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
  // Convert Uint8List to a JS-compatible ArrayBuffer
  final JSArrayBuffer jsArrayBuffer = image.buffer.toJS;

  // Create a Blob from the ArrayBuffer
  final web.Blob blob = web.Blob(
    <JSArrayBuffer>[jsArrayBuffer].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );

  // Generate an object URL for the Blob
  final String url = web.URL.createObjectURL(blob);

  // Create an anchor element for downloading the file
  final web.HTMLAnchorElement anchor =
      web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.target = '_blank';
  anchor.download = fileName;

  // Trigger the download
  anchor.click();

  // Revoke the object URL after the download
  web.URL.revokeObjectURL(url);
}
