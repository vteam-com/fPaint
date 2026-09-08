// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/export_prepare.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:web/web.dart' as web;

const String _htmlAnchorTag = 'a';

/// Writes the file straight to the browser's downloads.
///
/// The web build has no save dialog, so the dialog arguments are ignored; the
/// signature matches the desktop build so callers stay platform-agnostic.
/// Format-agnostic on purpose — see the non-web counterpart.
Future<void> exportToDestination({
  required String dialogTitle,
  required String suggestedFileName,
  required List<String> allowedExtensions,
  required Future<void> Function(String) write,
  AppPreferences? preferences,
  String Function(String)? resolveRecentFilePath,
}) async {
  // The browser picks the destination itself, so the dialog title and the
  // extension filter have nowhere to go, and there is no recent-file list to
  // record. Only the resolved name reaches the download.
  _ignoreDesktopOnlyArguments(dialogTitle, allowedExtensions, preferences);
  final String downloadName = resolveRecentFilePath?.call(suggestedFileName) ?? suggestedFileName;
  await write(downloadName);
}

/// Consumes the arguments the desktop save dialog needs and the web build has
/// no use for, keeping one shared [exportToDestination] signature.
void _ignoreDesktopOnlyArguments(
  String dialogTitle,
  List<String> allowedExtensions,
  AppPreferences? preferences,
) {
  if (dialogTitle.isEmpty || allowedExtensions.isEmpty || preferences == null) {
    return;
  }
}

/// Saves the current canvas as a PNG file and triggers a browser download.
Future<void> saveAsPng(
  LayersProvider layers,
  String filePath,
) async {
  downloadBlob(await preparePngBytes(layers), filePath);
}

/// Saves the current content as a JPEG file and triggers a browser download.
Future<void> saveAsJpeg(
  LayersProvider layers,
  String filePath,
) async {
  downloadBlob(await prepareJpegBytes(layers), filePath);
}

/// Saves the current project as an ORA (OpenRaster) file and triggers a browser download.
Future<void> saveAsOra(
  LayersProvider layers,
  String filePath,
) async {
  downloadBlob(await prepareOraBytes(layers), filePath);
}

/// Saves all layers as a layered TIFF file and triggers a browser download.
Future<void> saveAsTiff(
  LayersProvider layers,
  String? filePath,
) async {
  if (filePath != null) {
    final Uint8List tiffBytes = await convertLayersToTiff(layers);
    downloadBlob(tiffBytes, normalizeTiffExportFileName(filePath));
    layers.clearHasChanged();
  }
}

/// Saves the current content as a WebP file and triggers a browser download.
Future<void> saveAsWebp(
  LayersProvider layers,
  String filePath,
) async {
  downloadBlob(await prepareWebpBytes(layers), filePath);
}

/// Saves the current content as a HEIC file and triggers a browser download.
Future<void> saveAsHeic(
  LayersProvider layers,
  String filePath,
) async {
  downloadBlob(await prepareHeicBytes(layers), filePath);
}

/// Downloads a file represented by the given image bytes and file name.
///
/// This function creates a Blob from the provided image bytes, generates an
/// object URL for the Blob, creates an anchor element for downloading the file,
/// triggers the download, and then revokes the object URL.
///
/// [image] The image bytes to be downloaded.
/// [fileName] The name of the file to be downloaded.
void downloadBlob(Uint8List image, String fileName) {
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
