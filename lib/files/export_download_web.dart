// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/export_prepare.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:web/web.dart' as web;

const String _htmlAnchorTag = 'a';

/// Exports the current painter as a PNG image and triggers a download.
///
/// This function captures the current painter's image bytes and creates a PNG
/// file that is then downloaded to the user's device.
///
/// [context] The BuildContext to access the current AppProvider.
Future<void> onExportAsPng(
  final LayersProvider layers, [
  final String fileName = 'image.png',
]) async {
  await saveAsPng(layers, fileName);
}

/// Saves the current canvas as a PNG file and triggers a browser download.
Future<void> saveAsPng(
  final LayersProvider layers,
  final String filePath,
) async {
  downloadBlob(await preparePngBytes(layers), filePath);
}

/// Exports the current painter as a JPG image and triggers a download.
///
/// This function captures the current painter's image bytes, converts it to JPG,
/// and creates a JPG file that is then downloaded to the user's device.
///
/// [context] The BuildContext to access the current AppProvider.
Future<void> onExportAsJpeg(
  final LayersProvider layers, [
  final String fileName = 'image.jpg',
]) async {
  await saveAsJpeg(layers, fileName);
}

/// Saves the current content as a JPEG file and triggers a browser download.
Future<void> saveAsJpeg(
  final LayersProvider layers,
  final String filePath,
) async {
  downloadBlob(await prepareJpegBytes(layers), filePath);
}

/// Exports the current painter as an ORA file and triggers a download.
///
/// This function captures the current painter's image bytes, creates an ORA
/// archive, and then downloads the file to the user's device.
///
/// [context] The BuildContext to access the current AppProvider.
Future<void> onExportAsOra(
  final LayersProvider layers, [
  final String fileName = 'image.ora',
]) async {
  await saveAsOra(layers, fileName);
}

/// Saves the current project as an ORA (OpenRaster) file and triggers a browser download.
Future<void> saveAsOra(
  final LayersProvider layers,
  final String filePath,
) async {
  downloadBlob(await prepareOraBytes(layers), filePath);
}

/// Exports the current painter as a WebP image and triggers a download.
Future<void> onExportAsWebp(
  final LayersProvider layers, [
  final String fileName = 'image.webp',
]) async {
  await saveAsWebp(layers, fileName);
}

/// Exports all layers as a layered TIFF and triggers download.
Future<void> onExportAsTiff(
  final LayersProvider layers, [
  final String fileName = defaultTiffExportFileName,
]) async {
  final Uint8List tiffBytes = await convertLayersToTiff(layers);
  downloadBlob(tiffBytes, normalizeTiffExportFileName(fileName));
  layers.clearHasChanged();
}

/// Saves the current content as a WebP file and triggers a browser download.
Future<void> saveAsWebp(
  final LayersProvider layers,
  final String filePath,
) async {
  downloadBlob(await prepareWebpBytes(layers), filePath);
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
  final web.HTMLAnchorElement anchor = web.document.createElement(_htmlAnchorTag) as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.target = '_blank';
  anchor.download = fileName;

  // Trigger the download
  anchor.click();

  // Revoke the object URL after the download
  web.URL.revokeObjectURL(url);
}
