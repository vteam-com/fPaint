// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/share_panel.dart';

Future<void> onExportAsPng(final BuildContext context) async {
  // Capture the image bytes
  final Uint8List image = await capturePainterToImageBytes(context);

  // Create a Blob from the image bytes
  downloadBlob(image, 'image.png');
}

Future<void> onExportAsOra(
  final BuildContext context,
  final AppModel appModel,
) async {
  List<int> image = await createOraAchive(appModel);
  downloadBlob(Uint8List.fromList(image), 'image.ora');
}

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
