import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/share_panel.dart';

Future<void> onExportAsPng(final BuildContext context) async {
  final AppModel appModel = AppModel.get(context);
  // Capture the image bytes
  final String? filePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save image',
    fileName: 'image.png',
    allowedExtensions: ['png'],
    type: FileType.custom,
  );
  if (filePath != null) {
    final Uint8List image = await capturePainterToImageBytes(appModel);
    await File(filePath).writeAsBytes(image);
  }
}

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
