// ignore: fcheck_dead_code
import 'dart:io';

import 'package:flutter/services.dart';

const String _imageMethod = 'image';
const String _writeImageMethod = 'writeImage';
const String _fileNameKey = 'fileName';
const String _channelName = 'pasteboard';

/// Provides image clipboard access for desktop platforms.
class Pasteboard {
  /// Reads a PNG image from the system clipboard.
  static Future<Uint8List?> get image async {
    final Object? value = await _channel.invokeMethod<Object>(_imageMethod);
    if (value == null || !Platform.isWindows) {
      return value as Uint8List?;
    }
    final File file = File(value as String);
    final Uint8List bytes = await file.readAsBytes();
    await file.delete();
    return bytes;
  }

  /// Writes PNG [image] bytes to the system clipboard.
  static Future<void> writeImage(Uint8List? image) async {
    if (image == null || !Platform.isWindows) {
      return;
    }
    final File file = File('${Directory.systemTemp.path}/fpaint_clipboard.png');
    await file.writeAsBytes(image, flush: true);
    try {
      await _channel.invokeMethod<void>(_writeImageMethod, <String, String>{_fileNameKey: file.path});
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static const MethodChannel _channel = MethodChannel(_channelName);
}
