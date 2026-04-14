import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

/// Converts encoded image bytes into TIFF-encoded bytes.
Future<Uint8List> convertToTiff(final Uint8List inputBytes) async {
  final img.Image? image = img.decodeImage(inputBytes);
  if (image == null) {
    throw Exception('Failed to decode image for TIFF conversion');
  }
  final Uint8List outputBytes = img.encodeTiff(image);
  return Uint8List.fromList(outputBytes);
}

final Logger _log = Logger(logNameFileTiff);

/// Decodes TIFF bytes and populates [layers] with one layer per TIFF frame.
Future<void> readTiffFileFromBytes(
  final LayersProvider layers,
  final Uint8List bytes,
) async {
  final img.TiffDecoder decoder = img.TiffDecoder();
  final img.TiffInfo? tiffInfo = decoder.startDecode(bytes);

  if (tiffInfo == null) {
    layers.clear();
    layers.addWhiteBackgroundLayer();
    layers.size = const Size(AppLayout.minPanelExtent, AppLayout.minPanelExtent);
    _log.severe('Failed to decode TIFF info. Added default background.');
    layers.clearHasChanged();
    throw Exception('Invalid TIFF data or unable to read TIFF info.');
  }

  layers.clear();
  layers.size = Size(tiffInfo.width.toDouble(), tiffInfo.height.toDouble());

  final int numFrames = decoder.numFrames();

  if (numFrames == 0) {
    layers.addWhiteBackgroundLayer();
    _log.warning('TIFF file contained no image frames. Added default background.');
    layers.clearHasChanged();
    return;
  }

  for (int i = numFrames - 1; i >= 0; i--) {
    final img.Image? frame = decoder.decodeFrame(i);

    if (frame == null) {
      _log.warning('Failed to decode frame $i from TIFF.');
      continue;
    }

    String layerName = 'Layer ${i + 1}';

    // Try to extract name from TIFF tags if available
    if (frame is img.TiffImage) {
      final img.TiffImage tiffFrame = frame as img.TiffImage;
      const int imageDescriptionTagId = 270;

      if (tiffFrame.tags.containsKey(imageDescriptionTagId)) {
        final dynamic tagValue = tiffFrame.tags[imageDescriptionTagId];

        if (tagValue is String) {
          final String description = tagValue.trim();
          if (description.isNotEmpty) {
            layerName = description;
          }
        } else if (tagValue is List<int>) {
          // Sometimes tag values may be a list of char codes, try to decode:
          final String description = String.fromCharCodes(tagValue).trim();
          if (description.isNotEmpty) {
            layerName = description;
          }
        } else {
          // fallback: convert to string
          final String description = tagValue.toString().trim();
          if (description.isNotEmpty) {
            layerName = description;
          }
        }
      }
    }
    final LayerProvider newLayer = layers.addTop(name: layerName);

    final Uint8List pngBytes = img.encodePng(frame);
    final ui.Image uiFrameImage = await _decodeImageFromList(pngBytes);

    newLayer.addImage(
      imageToAdd: uiFrameImage,
      offset: Offset.zero, // No offsets available from frame
    );
  }

  if (layers.isEmpty) {
    layers.addWhiteBackgroundLayer();
    _log.warning('No layers were decoded. Added default background.');
  }

  layers.selectedLayerIndex = 0;
  layers.clearHasChanged();
}

/// Loads a TIFF file from disk and decodes it into [layers].
Future<void> readTiffFromFilePath(
  final LayersProvider layers,
  final String path,
) async {
  final Uint8List bytes = await File(path).readAsBytes();
  await readTiffFileFromBytes(layers, bytes);
}

// Private helper to convert Uint8List to ui.Image
Future<ui.Image> _decodeImageFromList(final Uint8List list) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromList(list, (final ui.Image img) {
    completer.complete(img);
  });
  return completer.future;
}
