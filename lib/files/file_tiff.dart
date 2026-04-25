import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

part 'file_tiff_encoder.dart';

const String _errorNoLayersToExportAsTiff = 'No layers to export as TIFF.';
const String _errorCompositeRasterizationFailed = 'Failed to rasterize layered TIFF composite.';
const String _errorTiffFileNotFoundPrefix = 'TIFF file not found:';
const String _errorTiffReadFilePrefix = 'Failed to read TIFF file:';
const String _errorInvalidTiffData = 'Invalid TIFF data or unable to read TIFF info.';
const String _errorNoTiffFrames = 'TIFF file contained no image frames.';
const String _errorNoDecodedTiffLayers = 'No layers could be decoded from TIFF file.';

/// Converts all layers from [layers] into a layered TIFF with a flattened root
/// image and one SubIFD per layer, bottom-to-top.
Future<Uint8List> convertLayersToTiff(final LayersProvider layers) async {
  final List<_LayerFrame> layerFrames = await _buildLayerFrames(layers);
  final img.Image compositeImage = await _buildCompositeFrame(layers);

  return _encodeLayeredTiff(
    compositeImage: compositeImage,
    layerFrames: layerFrames,
  );
}

/// Serializes layer properties into a JSON string for ImageDescription.
String _encodeLayerMetadata(final LayerProvider layer) {
  return jsonEncode(<String, dynamic>{
    TiffConstants.metaKeyName: layer.name,
    TiffConstants.metaKeyOpacity: layer.opacity,
    TiffConstants.metaKeyBlendMode: layer.blendMode.name,
    TiffConstants.metaKeyVisible: layer.isVisible,
  });
}

/// A decoded layer frame ready for TIFF encoding.
class _LayerFrame {
  _LayerFrame({
    required this.image,
    required this.description,
    required this.layerName,
    required this.offset,
  });

  final img.Image image;

  /// JSON-encoded layer metadata for the ImageDescription tag.
  final String description;

  /// Plain layer name for PageName and vendor compatibility tags.
  final String layerName;

  /// Top-left canvas position for the cropped layer pixels.
  final Offset offset;
}

/// Renders each layer, crops away transparent margins, and prepares TIFF pages.
Future<List<_LayerFrame>> _buildLayerFrames(final LayersProvider layers) async {
  final List<_LayerFrame> frames = <_LayerFrame>[];

  for (int i = layers.length - 1; i >= 0; i--) {
    final LayerProvider layer = layers.get(i);
    final ui.Image layerImage = layer.toImageForStorage(layers.size);
    final Rect exportBounds = await _resolveLayerExportBounds(layerImage, layers.size);
    final ui.Image croppedLayerImage = cropImage(layerImage, exportBounds);
    final img.Image? decoded = await _decodeUiImageToPackageImage(croppedLayerImage);

    if (decoded == null) {
      continue;
    }

    frames.add(
      _LayerFrame(
        image: decoded,
        description: _encodeLayerMetadata(layer),
        layerName: layer.name,
        offset: exportBounds.topLeft,
      ),
    );
  }

  if (frames.isEmpty) {
    throw const TiffFileException(_errorNoLayersToExportAsTiff);
  }

  return frames;
}

Future<img.Image> _buildCompositeFrame(final LayersProvider layers) async {
  final img.Image? compositeImage = await _decodeUiImageToPackageImage(
    await layers.capturePainterToImage(),
  );

  if (compositeImage == null) {
    throw const TiffFileException(_errorCompositeRasterizationFailed);
  }

  return compositeImage;
}

/// Returns the export bounds for a layer, falling back to the full canvas when blank.
Future<Rect> _resolveLayerExportBounds(
  final ui.Image layerImage,
  final Size canvasSize,
) async {
  final Rect? bounds = await getNonTransparentBounds(layerImage);
  if (bounds == null) {
    return Offset.zero & canvasSize;
  }

  return Rect.fromLTRB(
    bounds.left.floorToDouble(),
    bounds.top.floorToDouble(),
    bounds.right.ceilToDouble(),
    bounds.bottom.ceilToDouble(),
  );
}

Future<img.Image?> _decodeUiImageToPackageImage(final ui.Image uiImage) async {
  final ByteData? byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    return null;
  }

  return img.decodeImage(byteData.buffer.asUint8List());
}

final Logger _log = Logger(logNameFileTiff);

/// Decodes TIFF bytes and populates [layers] with one layer per TIFF frame.
///
/// Layer metadata (name, opacity, blend mode, visibility) is restored from
/// the ImageDescription tag when the payload is a JSON object written by
/// [convertLayersToTiff].  Plain-text descriptions are treated as the layer
/// name for backward compatibility with third-party TIFF files.
Future<void> readTiffFileFromBytes(
  final LayersProvider layers,
  final Uint8List bytes,
) async {
  final _DecodedTiffDocument decodedDocument = _decodeTiffDocument(bytes);

  layers.clear();
  layers.size = decodedDocument.size;

  for (final _DecodedTiffLayer layer in decodedDocument.layers) {
    await _appendDecodedTiffLayer(layers, meta: layer.meta, image: layer.image, offset: layer.offset);
  }

  layers.selectedLayerIndex = 0;
  layers.clearHasChanged();
}

/// Decodes [bytes] into a validated TIFF document model ready to apply.
///
/// This parses the TIFF header, prefers layered SubIFD content when present,
/// falls back to frame-by-frame decoding for flat TIFFs, and throws a
/// [TiffFileException] when the payload is invalid or contains no usable
/// layers.
_DecodedTiffDocument _decodeTiffDocument(final Uint8List bytes) {
  final img.TiffDecoder decoder = img.TiffDecoder();
  final img.TiffInfo? tiffInfo = decoder.startDecode(bytes);

  if (tiffInfo == null) {
    throw const TiffFileException(_errorInvalidTiffData);
  }

  final List<_DecodedTiffLayer>? subIfdLayers = _tryDecodeSubIfdLayers(bytes, tiffInfo);
  final List<_DecodedTiffLayer> decodedLayers = subIfdLayers ?? _decodeFrameLayers(decoder, tiffInfo);
  if (decodedLayers.isEmpty) {
    throw const TiffFileException(_errorNoDecodedTiffLayers);
  }

  return _DecodedTiffDocument(
    size: Size(tiffInfo.width.toDouble(), tiffInfo.height.toDouble()),
    layers: decodedLayers,
  );
}

/// Decodes standard TIFF frames into layer models when no SubIFD layers exist.
///
/// Frames are read back-to-front so the resulting layer order matches the
/// painting stack expected by [LayersProvider]. Any undecodable frame is skipped
/// with a warning, while an entirely empty TIFF still fails with a
/// [TiffFileException].
List<_DecodedTiffLayer> _decodeFrameLayers(
  final img.TiffDecoder decoder,
  final img.TiffInfo tiffInfo,
) {
  final int numFrames = decoder.numFrames();
  if (numFrames == 0) {
    throw const TiffFileException(_errorNoTiffFrames);
  }

  final List<_DecodedTiffLayer> decodedLayers = <_DecodedTiffLayer>[];
  for (int i = numFrames - 1; i >= 0; i--) {
    final img.Image? frame = decoder.decodeFrame(i);

    if (frame == null) {
      _log.warning('Failed to decode frame $i from TIFF.');
      continue;
    }

    decodedLayers.add(
      _DecodedTiffLayer(
        image: frame,
        meta: _extractLayerMeta(tiffInfo, i),
        offset: Offset.zero,
      ),
    );
  }

  return decodedLayers;
}

class _DecodedTiffDocument {
  _DecodedTiffDocument({
    required this.size,
    required this.layers,
  });

  final Size size;
  final List<_DecodedTiffLayer> layers;
}

class _DecodedTiffLayer {
  _DecodedTiffLayer({
    required this.image,
    required this.meta,
    required this.offset,
  });

  final img.Image image;
  final _LayerMeta meta;
  final Offset offset;
}

/// Decodes SketchBook-style layer pages stored in a root SubIFD array.
List<_DecodedTiffLayer>? _tryDecodeSubIfdLayers(
  final Uint8List bytes,
  final img.TiffInfo tiffInfo,
) {
  if (tiffInfo.images.isEmpty) {
    return null;
  }

  final img.TiffImage rootImage = tiffInfo.images.first;
  final List<int> subIfdOffsets = _readIntTagList(rootImage, TiffConstants.tagSubIfd);
  if (subIfdOffsets.isEmpty) {
    return null;
  }

  final bool isBigEndian = tiffInfo.bigEndian ?? false;
  final List<_DecodedTiffLayer> decodedLayers = <_DecodedTiffLayer>[];

  for (final int subIfdOffset in subIfdOffsets) {
    final img.TiffImage? subIfdImage = _readTiffImageAtOffset(bytes, isBigEndian, subIfdOffset);
    if (subIfdImage == null || !subIfdImage.isValid || _shouldSkipSubIfdImage(subIfdImage)) {
      continue;
    }

    final img.Image decodedImage = subIfdImage.decode(img.InputBuffer(bytes, bigEndian: isBigEndian));

    if (_readIntTag(subIfdImage, TiffConstants.tagOrientation) == TiffConstants.orientationBottomLeft) {
      img.flipVertical(decodedImage);
    }

    if (_readIntTag(subIfdImage, TiffConstants.tagExtraSamples) == TiffConstants.extraSamplesAssociatedAlpha) {
      _unMultiplyAlpha(decodedImage);
    }

    decodedLayers.add(
      _DecodedTiffLayer(
        image: decodedImage,
        meta: _extractSubIfdLayerMeta(subIfdImage, decodedLayers.length),
        offset: _extractSubIfdOffset(subIfdImage),
      ),
    );
  }

  return decodedLayers.isEmpty ? null : decodedLayers;
}

/// Reads a TIFF image directory directly from [subIfdOffset].
img.TiffImage? _readTiffImageAtOffset(
  final Uint8List bytes,
  final bool isBigEndian,
  final int subIfdOffset,
) {
  try {
    return img.TiffImage(
      img.InputBuffer(
        bytes,
        bigEndian: isBigEndian,
        offset: subIfdOffset,
      ),
    );
  } catch (_) {
    return null;
  }
}

bool _shouldSkipSubIfdImage(final img.TiffImage tiffImage) {
  final int? newSubfileType = _readIntTag(tiffImage, TiffConstants.tagNewSubfileType);
  final String? pageName = _readTextTag(tiffImage, TiffConstants.tagPageName);

  return newSubfileType == TiffConstants.subfileTypeReducedResolution || pageName == TiffConstants.pageNameThumbnail;
}

Offset _extractSubIfdOffset(final img.TiffImage tiffImage) {
  final double xPosition = _readDoubleTag(tiffImage, TiffConstants.tagXPosition) ?? 0.0;
  final double yPosition = _readDoubleTag(tiffImage, TiffConstants.tagYPosition) ?? 0.0;
  return Offset(xPosition, yPosition);
}

/// Builds layer metadata for a SketchBook-style SubIFD image.
_LayerMeta _extractSubIfdLayerMeta(
  final img.TiffImage tiffImage,
  final int layerIndex,
) {
  final String? description = _readDescriptionTag(tiffImage);
  if (description != null && description.isNotEmpty) {
    final _LayerMeta? parsed = _tryParseJsonMeta(description, layerIndex);
    if (parsed != null) {
      return parsed;
    }

    return _LayerMeta(
      name: description,
      opacity: 1.0,
      blendMode: ui.BlendMode.srcOver,
      visible: true,
    );
  }

  final String? pageName = _readTextTag(tiffImage, TiffConstants.tagPageName);
  final String? sketchBookLayerName = _readTextTag(tiffImage, TiffConstants.tagSketchBookLayerName);

  return _LayerMeta(
    name: pageName ?? sketchBookLayerName ?? _fallbackLayerName(layerIndex),
    opacity: 1.0,
    blendMode: ui.BlendMode.srcOver,
    visible: true,
  );
}

String _fallbackLayerName(final int layerIndex) {
  final StringBuffer buffer = StringBuffer(TiffConstants.fallbackLayerNamePrefix);
  buffer.write(TiffConstants.fallbackLayerNameSeparator);
  buffer.write(layerIndex + 1);
  return buffer.toString();
}

List<int> _readIntTagList(
  final img.TiffImage tiffImage,
  final int tag,
) {
  final img.IfdValue? value = tiffImage.tags[tag]?.read();
  if (value == null || value.length == 0) {
    return const <int>[];
  }

  return List<int>.generate(value.length, (final int index) => value.toInt(index));
}

int? _readIntTag(
  final img.TiffImage tiffImage,
  final int tag,
) {
  final img.IfdValue? value = tiffImage.tags[tag]?.read();
  if (value == null || value.length == 0) {
    return null;
  }

  return value.toInt();
}

double? _readDoubleTag(
  final img.TiffImage tiffImage,
  final int tag,
) {
  final img.IfdValue? value = tiffImage.tags[tag]?.read();
  if (value == null || value.length == 0) {
    return null;
  }

  return value.toDouble();
}

/// Reads ASCII or byte-backed text from a TIFF tag.
String? _readTextTag(
  final img.TiffImage tiffImage,
  final int tag,
) {
  final img.IfdValue? value = tiffImage.tags[tag]?.read();
  if (value == null || value.length == 0) {
    return null;
  }

  if (value.typeString == TiffConstants.ifdValueTypeAscii) {
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  final List<int> bytes = value.toData().where((final int byte) => byte != 0).toList(growable: false);
  if (bytes.isEmpty) {
    return null;
  }

  final String text = String.fromCharCodes(bytes).trim();
  return text.isEmpty ? null : text;
}

/// Converts associated-alpha TIFF pixels into straight-alpha PNG pixels.
void _unMultiplyAlpha(final img.Image image) {
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final img.Pixel pixel = image.getPixel(x, y);
      final int alpha = pixel.a.toInt();

      if (alpha <= 0) {
        pixel.r = 0;
        pixel.g = 0;
        pixel.b = 0;
        continue;
      }

      if (alpha >= AppLimits.rgbChannelMax) {
        continue;
      }

      pixel.r = _unMultiplyChannel(pixel.r.toInt(), alpha);
      pixel.g = _unMultiplyChannel(pixel.g.toInt(), alpha);
      pixel.b = _unMultiplyChannel(pixel.b.toInt(), alpha);
    }
  }
}

int _unMultiplyChannel(
  final int channel,
  final int alpha,
) {
  return (channel * AppLimits.rgbChannelMax / alpha).round().clamp(0, AppLimits.rgbChannelMax);
}

/// Appends one decoded TIFF layer to the canvas, preserving placement.
Future<void> _appendDecodedTiffLayer(
  final LayersProvider layers, {
  required final _LayerMeta meta,
  required final img.Image image,
  required final Offset offset,
}) async {
  final LayerProvider newLayer = layers.addTop(name: meta.name);
  newLayer.opacity = meta.opacity;
  newLayer.blendMode = meta.blendMode;
  newLayer.isVisible = meta.visible;

  final Uint8List pngBytes = img.encodePng(image);
  final ui.Image uiFrameImage = await _decodeImageFromList(pngBytes);

  newLayer.addImage(
    imageToAdd: uiFrameImage,
    offset: offset,
  );
}

/// Parsed layer metadata extracted from a TIFF frame's ImageDescription tag.
class _LayerMeta {
  _LayerMeta({
    required this.name,
    required this.opacity,
    required this.blendMode,
    required this.visible,
  });

  final String name;
  final double opacity;
  final ui.BlendMode blendMode;
  final bool visible;
}

/// Reads the ImageDescription tag from the [frameIndex]-th frame of
/// [tiffInfo] and parses layer metadata.  Falls back to sensible defaults
/// when the tag is missing or not JSON.
_LayerMeta _extractLayerMeta(final img.TiffInfo tiffInfo, final int frameIndex) {
  String layerName = _fallbackLayerName(frameIndex);
  final double opacity = 1.0;
  final ui.BlendMode blendMode = ui.BlendMode.srcOver;
  final bool visible = true;

  if (frameIndex < tiffInfo.images.length) {
    final img.TiffImage tiffImage = tiffInfo.images[frameIndex];
    final String? description = _readDescriptionTag(tiffImage);

    if (description != null && description.isNotEmpty) {
      // Try to parse as our JSON metadata format.
      final _LayerMeta? parsed = _tryParseJsonMeta(description, frameIndex);
      if (parsed != null) {
        return parsed;
      }
      // Otherwise treat the whole string as a plain layer name.
      layerName = description;
    }
  }

  return _LayerMeta(
    name: layerName,
    opacity: opacity,
    blendMode: blendMode,
    visible: visible,
  );
}

/// Reads the ImageDescription string from a [tiffImage]'s tag map.
String? _readDescriptionTag(final img.TiffImage tiffImage) {
  return _readTextTag(tiffImage, TiffConstants.tagImageDescription);
}

/// Attempts to decode [description] as a JSON object carrying layer metadata.
/// Returns `null` if parsing fails or the string is not valid JSON object.
_LayerMeta? _tryParseJsonMeta(final String description, final int frameIndex) {
  if (!description.startsWith('{')) {
    return null;
  }
  try {
    final Map<String, dynamic> map = jsonDecode(description) as Map<String, dynamic>;
    final String name = (map[TiffConstants.metaKeyName] as String?) ?? _fallbackLayerName(frameIndex);
    final double opacity = (map[TiffConstants.metaKeyOpacity] as num?)?.toDouble() ?? 1.0;
    final bool visible = (map[TiffConstants.metaKeyVisible] as bool?) ?? true;
    final String blendName = (map[TiffConstants.metaKeyBlendMode] as String?) ?? 'srcOver';

    ui.BlendMode blendMode = ui.BlendMode.srcOver;
    for (final ui.BlendMode mode in ui.BlendMode.values) {
      if (mode.name == blendName) {
        blendMode = mode;
        break;
      }
    }

    return _LayerMeta(
      name: name,
      opacity: opacity,
      blendMode: blendMode,
      visible: visible,
    );
  } on FormatException {
    return null;
  }
}

/// Loads a TIFF file from disk and decodes it into [layers].
Future<void> readTiffFromFilePath(
  final LayersProvider layers,
  final String path,
) async {
  final File tiffFile = File(path);
  if (!await tiffFile.exists()) {
    throw TiffFileException('$_errorTiffFileNotFoundPrefix "$path"');
  }

  try {
    final Uint8List bytes = await tiffFile.readAsBytes();
    await readTiffFileFromBytes(layers, bytes);
  } on TiffFileException {
    rethrow;
  } catch (error, stackTrace) {
    _throwTiffException(
      '$_errorTiffReadFilePrefix "$path"',
      error,
      stackTrace,
    );
  }
}

Never _throwTiffException(
  final String message,
  final Object error,
  final StackTrace stackTrace,
) {
  Error.throwWithStackTrace(
    TiffFileException(message, cause: error),
    stackTrace,
  );
}

// Private helper to convert Uint8List to ui.Image
Future<ui.Image> _decodeImageFromList(final Uint8List list) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromList(list, (final ui.Image img) {
    completer.complete(img);
  });
  return completer.future;
}
