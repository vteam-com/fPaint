import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/psd_constants.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

final Logger _log = Logger(logNameFilePsd);

const String _errorPsdFileNotFoundPrefix = 'PSD file not found:';
const String _errorPsdReadFilePrefix = 'Failed to read PSD file:';
const String _errorInvalidPsdData = 'Invalid PSD data or unable to read PSD info.';
const String _errorNoDecodedPsdLayers = 'No layers could be decoded from PSD file.';

/// One PSD layer resolved into everything the canvas needs to rebuild it.
class _DecodedPsdLayer {
  const _DecodedPsdLayer({
    required this.image,
    required this.name,
    required this.offset,
    required this.opacity,
    required this.blendMode,
    required this.visible,
  });

  /// The layer's own pixels, sized to its PSD bounding box (not the canvas).
  final img.Image image;

  final String name;

  /// Top-left position of [image] on the canvas.
  final Offset offset;

  final double opacity;
  final ui.BlendMode blendMode;
  final bool visible;
}

/// A validated PSD document ready to be applied to the canvas.
class _DecodedPsdDocument {
  const _DecodedPsdDocument({required this.size, required this.layers});

  final Size size;

  /// Decoded layers ordered bottom-to-top, matching PSD storage order.
  final List<_DecodedPsdLayer> layers;
}

/// Decodes PSD bytes and populates [layers] with one layer per PSD layer.
///
/// Layer name, opacity, blend mode, visibility and canvas position are restored
/// from the PSD layer records. PSD layer groups are flattened, since the canvas
/// has no groups: the folders themselves are dropped and their children become
/// ordinary layers, inheriting a hidden group's visibility. A PSD with no usable
/// layer records (a flattened document, or one saved without "Maximize
/// Compatibility" layer data) falls back to the merged composite as a single
/// layer.
Future<void> readPsdFileFromBytes(
  LayersProvider layers,
  Uint8List bytes,
) async {
  final _DecodedPsdDocument document = _decodePsdDocument(bytes);

  await layers.replaceAll(
    canvasSize: document.size,
    addLayers: () async {
      // PSD stores layers bottom-first; addTop stacks each new layer above the
      // previous one, so walking in storage order preserves the PSD z-order.
      for (final _DecodedPsdLayer layer in document.layers) {
        await _appendDecodedPsdLayer(layers, layer);
      }
    },
  );
}

/// Loads a PSD file from disk and decodes it into [layers].
Future<void> readPsdFromFilePath(
  LayersProvider layers,
  String path,
) {
  return readLayeredFileFromPath<PsdFileException>(
    path: path,
    readBytes: (Uint8List bytes) => readPsdFileFromBytes(layers, bytes),
    fileNotFoundPrefix: _errorPsdFileNotFoundPrefix,
    readFailedPrefix: _errorPsdReadFilePrefix,
    exceptionBuilder: PsdFileException.new,
  );
}

/// Runs the PSD decoder, turning malformed input into a null result.
///
/// Truncated or non-PSD bytes make the decoder read past its buffer and throw
/// low-level errors (`RangeError`, `ImageException`). Callers only need to know
/// the payload is unusable, so those are collapsed here and reported as a
/// [PsdFileException] by the caller.
img.PsdImage? _decodePsdBytes(Uint8List bytes) {
  try {
    return img.PsdDecoder().decodePsd(bytes);
  } catch (error) {
    _log.warning('Failed to decode PSD data', error);
    return null;
  }
}

/// Decodes [bytes] into a validated PSD document model ready to apply.
///
/// Throws a [PsdFileException] when the payload is not a readable PSD or
/// contains no usable pixels.
_DecodedPsdDocument _decodePsdDocument(Uint8List bytes) {
  final img.PsdImage? psd = _decodePsdBytes(bytes);

  if (psd == null || !psd.isValid) {
    throw const PsdFileException(_errorInvalidPsdData);
  }

  final List<_DecodedPsdLayer> decodedLayers = _decodePsdLayers(psd.layers);

  final Size canvasSize = Size(psd.width.toDouble(), psd.height.toDouble());

  if (decodedLayers.isEmpty) {
    if (psd.width <= 0 || psd.height <= 0) {
      throw const PsdFileException(_errorNoDecodedPsdLayers);
    }
    // Flattened PSD, or one whose layer data we cannot use: fall back to the
    // merged composite so the file still opens.
    decodedLayers.add(_decodeMergedPsd(psd));
  }

  return _DecodedPsdDocument(size: canvasSize, layers: decodedLayers);
}

/// Flattens PSD layer records into canvas-ready layers, bottom-to-top.
///
/// The canvas has no layer groups, so group folders are dropped and their
/// children become ordinary layers. A group's own visibility still has to be
/// honoured: hiding a group in Photoshop hides everything inside it, so a
/// hidden group's children are imported hidden. Groups nest, hence the stack.
List<_DecodedPsdLayer> _decodePsdLayers(List<img.PsdLayer> psdLayers) {
  final List<_DecodedPsdLayer> decoded = <_DecodedPsdLayer>[];
  // Index of each open group's folder record, innermost last. The folder record
  // closes the group but carries its visibility flag, so a layer's enclosing
  // groups can only be resolved by looking ahead to them.
  final List<int> openGroupFolderIndices = <int>[];
  final List<int> folderIndexForDivider = _matchGroupFolderRecords(psdLayers);

  for (int index = 0; index < psdLayers.length; index++) {
    final img.PsdLayer layer = psdLayers[index];
    switch (layer.type()) {
      case PsdConstants.layerTypeBoundingSectionDivider:
        openGroupFolderIndices.add(folderIndexForDivider[index]);
      case PsdConstants.layerTypeOpenFolder:
      case PsdConstants.layerTypeClosedFolder:
        if (openGroupFolderIndices.isNotEmpty) {
          openGroupFolderIndices.removeLast();
        }
      default:
        final _DecodedPsdLayer? pixelLayer = _decodePsdPixelLayer(
          layer,
          enclosingGroupsVisible: openGroupFolderIndices.every(
            (int folderIndex) => folderIndex < 0 || psdLayers[folderIndex].isVisible(),
          ),
        );
        if (pixelLayer != null) {
          decoded.add(pixelLayer);
        }
    }
  }

  return decoded;
}

/// Pairs each group's bounding divider with the folder record that closes it.
///
/// Returns, per layer index, the index of the matching folder record, or -1
/// when the entry is not a divider or the group is left unclosed by a
/// malformed file.
List<int> _matchGroupFolderRecords(List<img.PsdLayer> psdLayers) {
  final List<int> folderIndexForDivider = List<int>.filled(psdLayers.length, -1);
  final List<int> pendingDividers = <int>[];

  for (int index = 0; index < psdLayers.length; index++) {
    switch (psdLayers[index].type()) {
      case PsdConstants.layerTypeBoundingSectionDivider:
        pendingDividers.add(index);
      case PsdConstants.layerTypeOpenFolder:
      case PsdConstants.layerTypeClosedFolder:
        if (pendingDividers.isNotEmpty) {
          folderIndexForDivider[pendingDividers.removeLast()] = index;
        }
      default:
        break;
    }
  }

  return folderIndexForDivider;
}

/// Converts one pixel-bearing PSD layer record into a canvas-ready layer.
///
/// Returns null when the record carries no usable pixels (an empty or
/// zero-sized layer, such as an adjustment or text layer the decoder could not
/// rasterize).
_DecodedPsdLayer? _decodePsdPixelLayer(
  img.PsdLayer layer, {
  required bool enclosingGroupsVisible,
}) {
  final img.Image? image = layer.layerImage;
  if (image == null || layer.width <= 0 || layer.height <= 0) {
    return null;
  }

  return _DecodedPsdLayer(
    image: image,
    name: _resolveLayerName(layer.name),
    offset: Offset((layer.left ?? 0).toDouble(), (layer.top ?? 0).toDouble()),
    opacity: layer.opacity / AppLimits.rgbChannelMax,
    blendMode: blendModeFromPsdBlendMode(layer.blendMode),
    visible: enclosingGroupsVisible && layer.isVisible(),
  );
}

/// Builds a single-layer document from the PSD's merged composite image.
///
/// Used for flattened PSDs and for files whose layer records cannot be
/// rendered, so the document still opens with its visible artwork.
_DecodedPsdLayer _decodeMergedPsd(img.PsdImage psd) {
  // renderImage() composites the (possibly empty) stack and caches the result
  // in mergedImage, so it always yields a canvas-sized image.
  final img.Image merged = psd.mergedImage ?? psd.renderImage();

  return _DecodedPsdLayer(
    image: merged,
    name: PsdConstants.mergedLayerName,
    offset: Offset.zero,
    opacity: 1,
    blendMode: ui.BlendMode.srcOver,
    visible: true,
  );
}

/// Returns a usable layer name, falling back when the PSD stores none.
String _resolveLayerName(String? name) {
  final String trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? PsdConstants.unnamedLayerName : trimmed;
}

/// Appends one decoded PSD layer to the canvas, preserving its placement.
Future<void> _appendDecodedPsdLayer(
  LayersProvider layers,
  _DecodedPsdLayer decoded,
) async {
  final LayerProvider newLayer = layers.addTop(name: decoded.name);
  newLayer.opacity = decoded.opacity;
  newLayer.blendMode = decoded.blendMode;
  newLayer.isVisible = decoded.visible;

  final Uint8List pngBytes = img.encodePng(decoded.image);
  final ui.Image uiLayerImage = await _decodeImageFromList(pngBytes);

  newLayer.addImage(
    imageToAdd: uiLayerImage,
    offset: decoded.offset,
  );
}

/// Returns the embedded PSD composite as PNG bytes, for previews/thumbnails.
///
/// Returns null when the bytes are not a readable PSD.
Future<Uint8List?> extractPsdPreviewPngBytes(Uint8List bytes) async {
  try {
    final img.PsdImage? psd = _decodePsdBytes(bytes);
    if (psd == null || !psd.isValid) {
      return null;
    }

    return img.encodePng(psd.mergedImage ?? psd.renderImage());
  } catch (error) {
    _log.warning('Failed to extract PSD preview', error);
    return null;
  }
}

/// Private helper to convert Uint8List to ui.Image
Future<ui.Image> _decodeImageFromList(Uint8List list) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromList(list, (ui.Image image) {
    completer.complete(image);
  });
  return completer.future;
}
