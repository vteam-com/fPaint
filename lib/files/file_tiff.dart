import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/tiff_constants.dart';
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
Future<Uint8List> convertLayersToTiff(LayersProvider layers) async {
  final List<_LayerFrame> layerFrames = await _buildLayerFrames(layers);
  final img.Image compositeImage = await _buildCompositeFrame(layers);

  return _encodeLayeredTiff(
    compositeImage: compositeImage,
    layerFrames: layerFrames,
  );
}

/// Serializes layer properties into a JSON string for ImageDescription.
String _encodeLayerMetadata(
  LayerProvider layer, {
  required bool selected,
}) {
  return jsonEncode(<String, dynamic>{
    TiffConstants.metaKeyName: layer.name,
    TiffConstants.metaKeyOpacity: layer.opacity,
    TiffConstants.metaKeyBlendMode: layer.blendMode.name,
    TiffConstants.metaKeyVisible: layer.isVisible,
    TiffConstants.metaKeyLocked: layer.isLocked,
    TiffConstants.metaKeySelected: selected,
    TiffConstants.metaKeyChannelOrder: TiffConstants.channelOrderBgra,
  });
}

/// Serializes [layer] into a SketchBook LayerModel payload.
///
/// This keeps opacity, visibility, and blend mode readable by SketchBook, which
/// never sees fPaint's JSON ImageDescription. Blend modes SketchBook has no
/// ordinal for are written as Normal, matching how the importer treats unknown
/// ordinals.
String _encodeSketchBookLayerModel(LayerProvider layer) {
  final int blendOrdinal = _sketchBookBlendModeOrdinals[layer.blendMode] ?? 0;
  final int visibleFlag = layer.isVisible ? 1 : TiffConstants.layerModelHidden;

  return <String>[
    layer.opacity.toStringAsFixed(TiffConstants.layerModelOpacityDecimals),
    '00000000',
    '$visibleFlag',
    '0',
    '1',
    '0',
    '161',
    '$blendOrdinal',
    '0',
    '0',
    '00000',
  ].join('${TiffConstants.layerModelFieldSeparator} ');
}

/// A decoded layer frame ready for TIFF encoding.
class _LayerFrame {
  _LayerFrame({
    required this.image,
    required this.description,
    required this.layerName,
    required this.offset,
    required this.bottomUpOffsetY,
    required this.layerModel,
  });

  final img.Image image;

  /// JSON-encoded layer metadata for the ImageDescription tag.
  final String description;

  /// Plain layer name for PageName and vendor compatibility tags.
  final String layerName;

  /// Top-left canvas position for the cropped layer pixels.
  final Offset offset;

  /// Distance from the canvas bottom to the bottom of the cropped pixels.
  ///
  /// SketchBook's YPosition tag is measured from the bottom of the canvas, so
  /// this is what gets written rather than [offset]'s top-left `dy`.
  final double bottomUpOffsetY;

  /// SketchBook LayerModel payload carrying opacity, visibility, and blend mode.
  final String layerModel;
}

/// Renders each layer, crops away transparent margins, and prepares TIFF pages.
Future<List<_LayerFrame>> _buildLayerFrames(LayersProvider layers) async {
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
        description: _encodeLayerMetadata(layer, selected: i == layers.selectedLayerIndex),
        layerName: layer.name,
        offset: exportBounds.topLeft,
        bottomUpOffsetY: layers.size.height - exportBounds.bottom,
        layerModel: _encodeSketchBookLayerModel(layer),
      ),
    );
  }

  if (frames.isEmpty) {
    throw const TiffFileException(_errorNoLayersToExportAsTiff);
  }

  return frames;
}

Future<img.Image> _buildCompositeFrame(LayersProvider layers) async {
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
  ui.Image layerImage,
  Size canvasSize,
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

Future<img.Image?> _decodeUiImageToPackageImage(ui.Image uiImage) async {
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
  LayersProvider layers,
  Uint8List bytes,
) async {
  final _DecodedTiffDocument decodedDocument = _decodeTiffDocument(bytes);

  LayerProvider? selectedLayer;
  await layers.replaceAll(
    canvasSize: decodedDocument.size,
    addLayers: () async {
      for (final _DecodedTiffLayer layer in decodedDocument.layers) {
        final LayerProvider appended = await _appendDecodedTiffLayer(
          layers,
          meta: layer.meta,
          image: layer.image,
          offset: layer.offset,
        );
        if (layer.meta.selected) {
          selectedLayer = appended;
        }
      }
    },
  );

  // replaceAll resets the selection to the first layer, so restore afterwards.
  if (selectedLayer != null) {
    final int index = layers.getLayerIndex(selectedLayer!);
    if (index >= 0) {
      layers.selectedLayerIndex = index;
    }
  }
}

/// Decodes [bytes] into a validated TIFF document model ready to apply.
///
/// This parses the TIFF header, prefers layered SubIFD content when present,
/// falls back to frame-by-frame decoding for flat TIFFs, and throws a
/// [TiffFileException] when the payload is invalid or contains no usable
/// layers.
_DecodedTiffDocument _decodeTiffDocument(Uint8List bytes) {
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
  img.TiffDecoder decoder,
  img.TiffInfo tiffInfo,
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
  Uint8List bytes,
  img.TiffInfo tiffInfo,
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
  final double canvasHeight = tiffInfo.height.toDouble();
  final bool aliasAuthored = _isAliasAuthoredRoot(rootImage);
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

    if (_layerStoresBgraPixels(subIfdImage, aliasAuthored: aliasAuthored)) {
      _swapRedBlue(decodedImage);
    }

    if (_readIntTag(subIfdImage, TiffConstants.tagExtraSamples) == TiffConstants.extraSamplesAssociatedAlpha) {
      _unMultiplyAlpha(decodedImage);
    }

    decodedLayers.add(
      _DecodedTiffLayer(
        image: decodedImage,
        meta: _extractSubIfdLayerMeta(subIfdImage, decodedLayers.length),
        offset: _extractSubIfdOffset(subIfdImage, canvasHeight),
      ),
    );
  }

  return decodedLayers.isEmpty ? null : decodedLayers;
}

/// Reads a TIFF image directory directly from [subIfdOffset].
img.TiffImage? _readTiffImageAtOffset(
  Uint8List bytes,
  bool isBigEndian,
  int subIfdOffset,
) {
  try {
    return img.TiffImage(
      img.InputBuffer(
        bytes,
        bigEndian: isBigEndian,
        offset: subIfdOffset,
      ),
    );
  } catch (e, stackTrace) {
    _log.warning('Failed to decode TIFF sub-IFD image', e, stackTrace);
    return null;
  }
}

/// Returns true when the root directory was written by SketchBook / Alias.
bool _isAliasAuthoredRoot(img.TiffImage rootImage) {
  final String? software = _readTextTag(rootImage, TiffConstants.tagSoftware);
  return software != null && software.startsWith(TiffConstants.aliasSoftwarePrefix);
}

/// Returns true when a layer SubIFD stores its pixels in BGRA channel order.
///
/// SketchBook writes layer rasters as premultiplied BGRA even though the tags
/// claim RGB, while the root composite and thumbnail SubIFD stay RGBA. fPaint
/// exports declare their channel order in the JSON ImageDescription payload,
/// which SketchBook never writes on layers, so that JSON is the tiebreaker:
/// older fPaint exports without the key were RGBA and must not be swapped.
bool _layerStoresBgraPixels(
  img.TiffImage tiffImage, {
  required bool aliasAuthored,
}) {
  final String? description = _readDescriptionTag(tiffImage);
  if (description == null || !description.startsWith('{')) {
    return aliasAuthored;
  }

  try {
    final dynamic decoded = jsonDecode(description);
    return decoded is Map<String, dynamic> &&
        decoded[TiffConstants.metaKeyChannelOrder] == TiffConstants.channelOrderBgra;
  } on FormatException {
    return aliasAuthored;
  }
}

/// Swaps the red and blue channels of every pixel in [image] in place.
void _swapRedBlue(img.Image image) {
  for (final img.Pixel pixel in image) {
    final num red = pixel.r;
    pixel.r = pixel.b;
    pixel.b = red;
  }
}

bool _shouldSkipSubIfdImage(img.TiffImage tiffImage) {
  final int? newSubfileType = _readIntTag(tiffImage, TiffConstants.tagNewSubfileType);
  final String? pageName = _readTextTag(tiffImage, TiffConstants.tagPageName);

  return newSubfileType == TiffConstants.subfileTypeReducedResolution || pageName == TiffConstants.pageNameThumbnail;
}

/// Converts a SketchBook SubIFD position into a top-left canvas offset.
///
/// SketchBook writes XPosition/YPosition in pixels, but YPosition measures the
/// distance from the *bottom* of the canvas to the bottom of the layer tile
/// (it pairs with the bottom-left Orientation used for the layer rasters).
/// Flutter layers are placed from the top-left, so the vertical component has
/// to be mirrored against the canvas height or every layer lands too low.
Offset _extractSubIfdOffset(
  img.TiffImage tiffImage,
  double canvasHeight,
) {
  final double xPosition = _readDoubleTag(tiffImage, TiffConstants.tagXPosition) ?? 0.0;
  final double? yPosition = _readDoubleTag(tiffImage, TiffConstants.tagYPosition);

  if (yPosition == null) {
    return Offset(xPosition, 0.0);
  }

  return Offset(xPosition, canvasHeight - yPosition - tiffImage.height);
}

/// Builds layer metadata for a SketchBook-style SubIFD image.
_LayerMeta _extractSubIfdLayerMeta(
  img.TiffImage tiffImage,
  int layerIndex,
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
      locked: false,
    );
  }

  final String? pageName = _readTextTag(tiffImage, TiffConstants.tagPageName);
  final String? sketchBookLayerName = _readTextTag(tiffImage, TiffConstants.tagSketchBookLayerName);
  final _SketchBookLayerModel? layerModel = _parseSketchBookLayerModel(tiffImage);

  return _LayerMeta(
    name: pageName ?? sketchBookLayerName ?? _fallbackLayerName(layerIndex),
    opacity: layerModel?.opacity ?? 1.0,
    blendMode: layerModel?.blendMode ?? ui.BlendMode.srcOver,
    visible: layerModel?.visible ?? true,
    locked: false,
  );
}

/// SketchBook blend-mode ordinals mapped onto Flutter blend modes.
///
/// The ordinal lives in field 7 of the SketchBook LayerModel payload (tag 272 /
/// tag 50784) and follows SketchBook's own layer-mode menu order. Modes with no
/// Flutter equivalent are left out so they fall back to [ui.BlendMode.srcOver]
/// rather than rendering as something visibly wrong.
const Map<int, ui.BlendMode> _sketchBookBlendModes = <int, ui.BlendMode>{
  0: ui.BlendMode.srcOver, // Normal
  1: ui.BlendMode.multiply,
  2: ui.BlendMode.screen,
  3: ui.BlendMode.overlay,
  4: ui.BlendMode.darken,
  5: ui.BlendMode.lighten,
  6: ui.BlendMode.colorDodge,
  7: ui.BlendMode.colorBurn,
  8: ui.BlendMode.hardLight,
  9: ui.BlendMode.softLight,
  10: ui.BlendMode.difference,
  11: ui.BlendMode.exclusion,
  12: ui.BlendMode.hue,
  13: ui.BlendMode.saturation,
  14: ui.BlendMode.color,
  15: ui.BlendMode.luminosity,
};

/// Flutter blend modes mapped back onto SketchBook ordinals for export.
final Map<ui.BlendMode, int> _sketchBookBlendModeOrdinals = <ui.BlendMode, int>{
  for (final MapEntry<int, ui.BlendMode> entry in _sketchBookBlendModes.entries) entry.value: entry.key,
};

/// Layer properties recovered from a SketchBook LayerModel payload.
class _SketchBookLayerModel {
  const _SketchBookLayerModel({
    required this.opacity,
    required this.blendMode,
    required this.visible,
  });

  final double opacity;
  final ui.BlendMode blendMode;
  final bool visible;
}

/// Parses opacity, blend mode, and visibility from a SketchBook LayerModel tag.
///
/// The payload is a comma-separated list such as
/// `1.000, 00000000, 1, 0, 1, 0, 161, 1, 0, 0, 00000`, where field 0 is the
/// opacity, field 2 the visibility flag, and field 7 the blend-mode ordinal
/// (the example above is a multiply layer from a real SketchBook 8.7.1 file).
/// Returns `null` when the tag is absent or too short to trust, so callers keep
/// their existing defaults.
_SketchBookLayerModel? _parseSketchBookLayerModel(img.TiffImage tiffImage) {
  final String? payload =
      _readTextTag(tiffImage, TiffConstants.tagSketchBookLayerModel) ?? _readTextTag(tiffImage, TiffConstants.tagModel);

  if (payload == null) {
    return null;
  }

  final List<String> fields = payload
      .split(TiffConstants.layerModelFieldSeparator)
      .map((String field) => field.trim())
      .toList(growable: false);

  if (fields.length < TiffConstants.layerModelMinFieldCount) {
    return null;
  }

  final double opacity = (double.tryParse(fields[TiffConstants.layerModelIndexOpacity]) ?? 1.0).clamp(0.0, 1.0);
  final int? blendOrdinal = int.tryParse(fields[TiffConstants.layerModelIndexBlendMode]);
  final int? visibleFlag = int.tryParse(fields[TiffConstants.layerModelIndexVisible]);

  return _SketchBookLayerModel(
    opacity: opacity,
    blendMode: _sketchBookBlendModes[blendOrdinal] ?? ui.BlendMode.srcOver,
    visible: visibleFlag != TiffConstants.layerModelHidden,
  );
}

String _fallbackLayerName(int layerIndex) {
  final StringBuffer buffer = StringBuffer(TiffConstants.fallbackLayerNamePrefix);
  buffer.write(TiffConstants.fallbackLayerNameSeparator);
  buffer.write(layerIndex + 1);
  return buffer.toString();
}

List<int> _readIntTagList(
  img.TiffImage tiffImage,
  int tag,
) {
  final img.IfdValue? value = tiffImage.tags[tag]?.read();
  if (value == null || value.length == 0) {
    return const <int>[];
  }

  return List<int>.generate(value.length, (int index) => value.toInt(index));
}

int? _readIntTag(
  img.TiffImage tiffImage,
  int tag,
) {
  final img.IfdValue? value = tiffImage.tags[tag]?.read();
  if (value == null || value.length == 0) {
    return null;
  }

  return value.toInt();
}

double? _readDoubleTag(
  img.TiffImage tiffImage,
  int tag,
) {
  final img.IfdValue? value = tiffImage.tags[tag]?.read();
  if (value == null || value.length == 0) {
    return null;
  }

  return value.toDouble();
}

/// Reads ASCII or byte-backed text from a TIFF tag.
String? _readTextTag(
  img.TiffImage tiffImage,
  int tag,
) {
  final img.IfdValue? value = tiffImage.tags[tag]?.read();
  if (value == null || value.length == 0) {
    return null;
  }

  if (value.typeString == TiffConstants.ifdValueTypeAscii) {
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  final List<int> bytes = value.toData().where((int byte) => byte != 0).toList(growable: false);
  if (bytes.isEmpty) {
    return null;
  }

  final String text = String.fromCharCodes(bytes).trim();
  return text.isEmpty ? null : text;
}

/// Converts associated-alpha TIFF pixels into straight-alpha PNG pixels.
void _unMultiplyAlpha(img.Image image) {
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
  int channel,
  int alpha,
) {
  return (channel * AppLimits.rgbChannelMax / alpha).round().clamp(0, AppLimits.rgbChannelMax);
}

/// Appends one decoded TIFF layer to the canvas, preserving placement.
///
/// Returns the created [LayerProvider] so callers can restore the selection.
Future<LayerProvider> _appendDecodedTiffLayer(
  LayersProvider layers, {
  required _LayerMeta meta,
  required img.Image image,
  required Offset offset,
}) async {
  final LayerProvider newLayer = layers.addTop(name: meta.name);
  newLayer.opacity = meta.opacity;
  newLayer.blendMode = meta.blendMode;
  newLayer.isVisible = meta.visible;
  newLayer.isLocked = meta.locked;

  final Uint8List pngBytes = img.encodePng(image);
  final ui.Image uiFrameImage = await _decodeImageFromList(pngBytes);

  newLayer.addImage(
    imageToAdd: uiFrameImage,
    offset: offset,
  );
  return newLayer;
}

/// Parsed layer metadata extracted from a TIFF frame's ImageDescription tag.
class _LayerMeta {
  _LayerMeta({
    required this.name,
    required this.opacity,
    required this.blendMode,
    required this.visible,
    required this.locked,
    this.selected = false,
  });

  final String name;
  final double opacity;
  final ui.BlendMode blendMode;
  final bool visible;
  final bool locked;

  /// Whether this layer was the selected layer when the TIFF was written.
  final bool selected;
}

/// Reads the ImageDescription tag from the [frameIndex]-th frame of
/// [tiffInfo] and parses layer metadata.  Falls back to sensible defaults
/// when the tag is missing or not JSON.
_LayerMeta _extractLayerMeta(img.TiffInfo tiffInfo, int frameIndex) {
  String layerName = _fallbackLayerName(frameIndex);
  const double opacity = 1.0;
  const ui.BlendMode blendMode = ui.BlendMode.srcOver;
  const bool visible = true;
  const bool locked = false;

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
    locked: locked,
  );
}

/// Reads the ImageDescription string from a [tiffImage]'s tag map.
String? _readDescriptionTag(img.TiffImage tiffImage) {
  return _readTextTag(tiffImage, TiffConstants.tagImageDescription);
}

/// Attempts to decode [description] as a JSON object carrying layer metadata.
/// Returns `null` if parsing fails or the string is not valid JSON object.
_LayerMeta? _tryParseJsonMeta(String description, int frameIndex) {
  if (!description.startsWith('{')) {
    return null;
  }
  try {
    final Map<String, dynamic> map = jsonDecode(description) as Map<String, dynamic>;
    final String name = (map[TiffConstants.metaKeyName] as String?) ?? _fallbackLayerName(frameIndex);
    final double opacity = (map[TiffConstants.metaKeyOpacity] as num?)?.toDouble() ?? 1.0;
    final bool visible = (map[TiffConstants.metaKeyVisible] as bool?) ?? true;
    final bool locked = (map[TiffConstants.metaKeyLocked] as bool?) ?? false;
    final bool selected = (map[TiffConstants.metaKeySelected] as bool?) ?? false;
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
      locked: locked,
      selected: selected,
    );
  } on FormatException {
    return null;
  }
}

/// Loads a TIFF file from disk and decodes it into [layers].
Future<void> readTiffFromFilePath(
  LayersProvider layers,
  String path,
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
    throwFileOperationException<TiffFileException>(
      message: '$_errorTiffReadFilePrefix "$path"',
      error: error,
      stackTrace: stackTrace,
      exceptionBuilder: TiffFileException.new,
    );
  }
}

// Private helper to convert Uint8List to ui.Image
Future<ui.Image> _decodeImageFromList(Uint8List list) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromList(list, (ui.Image img) {
    completer.complete(img);
  });
  return completer.future;
}
