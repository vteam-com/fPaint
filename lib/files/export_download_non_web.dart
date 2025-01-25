import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/models/app_model.dart';

Future<void> onExportAsPng(final BuildContext context) async {
  // NOT USED FOR NON WEB CLIENT
}

Future<void> onExportAsOra(
  final BuildContext context,
  AppModel appModel,
) async {
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
