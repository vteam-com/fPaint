import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/decoded_layer_document.dart';
import 'package:fpaint/files/decoded_layer_pixels.dart';
import 'package:fpaint/files/decoded_raster_layer.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/png_encoder.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/layer_provider_storage_export.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

final Logger _log = Logger(logNameFileOra);

// ORA file format element and attribute identifiers
/// Name given to an ORA layer that stores none.
const String _oraUnnamedLayer = 'Unnamed';
const String _oraElementImage = 'image';
const String _oraElementStack = 'stack';
const String _oraElementLayer = 'layer';
const String _oraAttrWidth = 'w';
const String _oraAttrHeight = 'h';
const String _oraAttrName = 'name';
const String _oraAttrVersion = 'version';
const String _oraAttrVisibility = 'visibility';
const String _oraAttrOpacity = 'opacity';
const String _oraAttrSrc = 'src';
const String _oraAttrX = 'x';
const String _oraAttrY = 'y';
const String _oraAttrCompositeOp = 'composite-op';
const String _oraAttrAlphaPreserve = 'alpha-preserve';
const String _oraAttrEditLocked = 'edit-locked';
const String _oraAttrSelected = 'selected';
const String _oraVisibilityVisible = 'visible';
const String _oraVisibilityHidden = 'hidden';
const String _oraVisibilityInherit = 'inherit';
const String _booleanTextTrue = 'true';
const String _booleanTextFalse = 'false';
const String _oraXmlProcessingTarget = 'xml';
const String _oraXmlEncoding = 'version="1.0" encoding="UTF-8"';
const String _oraMimetypeEntry = 'mimetype';
const String _oraStackXmlEntry = 'stack.xml';
const String _oraMergedImageEntry = 'mergedimage.png';
const String _oraThumbnailEntry = 'Thumbnails/thumbnail.png';
const String _oraThumbnailEntryLowercase = 'thumbnails/thumbnail.png';
const String _errorOraReadBytes = 'Failed to read ORA bytes.';
const String _errorOraMissingStackXml = 'stack.xml not found in ORA file.';
const String _errorOraMissingImageElement = 'image element not found in ORA stack.xml.';
const String _errorOraMissingDimensions = 'ORA image dimensions are missing.';
const String _errorOraLayerEncodingFailed = 'Failed to encode ORA layer PNG.';
const String _oraLayerImageEntryPrefix = 'data/layer-';
const String _oraLayerImageEntrySuffix = '.png';
const String _oraLayerMetaParentGroupName = 'parentGroupName';

const List<String> _oraPreviewEntries = <String>[
  _oraThumbnailEntry,
  _oraThumbnailEntryLowercase,
  _oraMergedImageEntry,
];

/// Creates an [ArchiveFile] with a fixed timestamp so archives are
/// byte-identical across runs when the payload has not changed.
ArchiveFile _neutralArchiveFile(String name, List<int> data) {
  final ArchiveFile file = ArchiveFile.bytes(name, data);
  file.lastModTime = 0;
  return file;
}

/// Creates a deterministic [ArchiveFile] stored without ZIP recompression.
ArchiveFile _storedNeutralArchiveFile(String name, List<int> data) {
  final ArchiveFile file = _neutralArchiveFile(name, data);
  file.compression = CompressionType.none;
  return file;
}

/// Renders [layer], crops away transparent margins, and returns PNG bytes plus
/// the cropped image's original canvas offset for ORA `x`/`y` metadata.
Future<({Uint8List bytes, ui.Offset offset})> _prepareOraLayerExport({
  required LayerProvider layer,
  required PngEncodePool pool,
}) {
  final ui.Rect exportBounds = layer.estimateContentBoundsForStorage();
  final int pixels = (exportBounds.width * exportBounds.height).ceil();
  // Rendered only once the pool admits it, so at most the budgeted layers
  // hold a full-size GPU render and readback at a time.
  return pool.run(pixels, () async {
    final Uint8List? bytes = await encodeImageToPngFast(
      layer.toImageForStorageBounds(exportBounds),
      disposeAfterReadback: true,
    );
    if (bytes == null) {
      throw const OraFileException(_errorOraLayerEncodingFailed);
    }
    return (bytes: bytes, offset: exportBounds.topLeft);
  });
}

// SVG composite operation identifiers used in the ORA format
const String _svgSourceOver = 'svg:source-over';
const String _svgMultiply = 'svg:multiply';
const String _svgScreen = 'svg:screen';
const String _svgOverlay = 'svg:overlay';
const String _svgDarken = 'svg:darken';
const String _svgLighten = 'svg:lighten';
const String _svgColorDodge = 'svg:color-dodge';
const String _svgColorBurn = 'svg:color-burn';
const String _svgHardLight = 'svg:hard-light';
const String _svgSoftLight = 'svg:soft-light';
const String _svgDifference = 'svg:difference';
const String _svgExclusion = 'svg:exclusion';
const String _svgPlus = 'svg:plus';
const String _svgHue = 'svg:hue';
const String _svgSaturation = 'svg:saturation';
const String _svgColor = 'svg:color';
const String _svgLuminosity = 'svg:luminosity';
const String _svgSrcOverLegacy = 'svg:src-over';

/// ORA `composite-op` values and the blend modes they map to, one per mode.
const Map<String, ui.BlendMode> _oraCompositeOpBlendModes = <String, ui.BlendMode>{
  _svgSourceOver: ui.BlendMode.srcOver,
  _svgMultiply: ui.BlendMode.multiply,
  _svgScreen: ui.BlendMode.screen,
  _svgOverlay: ui.BlendMode.overlay,
  _svgDarken: ui.BlendMode.darken,
  _svgLighten: ui.BlendMode.lighten,
  _svgColorDodge: ui.BlendMode.colorDodge,
  _svgColorBurn: ui.BlendMode.colorBurn,
  _svgHardLight: ui.BlendMode.hardLight,
  _svgSoftLight: ui.BlendMode.softLight,
  _svgDifference: ui.BlendMode.difference,
  _svgExclusion: ui.BlendMode.exclusion,
  _svgPlus: ui.BlendMode.plus,
  _svgHue: ui.BlendMode.hue,
  _svgSaturation: ui.BlendMode.saturation,
  _svgColor: ui.BlendMode.color,
  _svgLuminosity: ui.BlendMode.luminosity,
};

/// Read-only aliases accepted on import but never written on export.
const Map<String, ui.BlendMode> _oraLegacyCompositeOpBlendModes = <String, ui.BlendMode>{
  _svgSrcOverLegacy: ui.BlendMode.srcOver,
};

/// Blend modes mapped back onto their canonical ORA `composite-op` for export.
final Map<ui.BlendMode, String> _oraBlendModeCompositeOps = <ui.BlendMode, String>{
  for (final MapEntry<String, ui.BlendMode> entry in _oraCompositeOpBlendModes.entries) entry.value: entry.key,
};

/// Read the file from  bytes
Future<void> readOraFileFromBytes(
  LayersProvider layers,
  Uint8List bytes,
) async {
  await wrapFileOperation<OraFileException, void>(
    message: _errorOraReadBytes,
    exceptionBuilder: OraFileException.new,
    operation: () async {
      // Extract the ZIP contents
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      // Find the stack.xml file
      final ArchiveFile stackFile = archive.files.firstWhere(
        (ArchiveFile file) => file.name == _oraStackXmlEntry,
        orElse: () => throw const OraFileException(_errorOraMissingStackXml),
      );

      // Parse the stack.xml content
      final XmlDocument xmlDoc = XmlDocument.parse(
        String.fromCharCodes(stackFile.content),
      );

      await applyDecodedDocument(layers, await decodeOraStack(archive, xmlDoc));
    },
  );
}

/// Returns the root `image` element of an ORA stack document, or throws.
XmlElement _requireOraImageElement(XmlDocument xmlDoc) {
  final XmlElement? xmlElementImage = xmlDoc.getElement(_oraElementImage);
  if (xmlElementImage == null) {
    throw const OraFileException(_errorOraMissingImageElement);
  }
  return xmlElementImage;
}

/// Extracts the canvas size from the ORA root `image` element.
ui.Size _extractOraCanvasSize(XmlElement xmlElementImage) {
  final String? width = xmlElementImage.getAttribute(_oraAttrWidth);
  final String? height = xmlElementImage.getAttribute(_oraAttrHeight);
  if (width == null || height == null) {
    throw const OraFileException(_errorOraMissingDimensions);
  }

  return ui.Size(double.parse(width), double.parse(height));
}

/// Decodes an ORA stack document into a layered document, without touching
/// any canvas state.
///
/// Layers come out bottom-to-top, the order [applyDecodedDocument] stacks
/// them in; ORA lists them top-first.
Future<DecodedRasterDocument> decodeOraStack(
  Archive archive,
  XmlDocument xmlDoc,
) async {
  final XmlElement xmlElementImage = _requireOraImageElement(xmlDoc);
  final List<DecodedRasterLayer> topFirst = <DecodedRasterLayer>[];
  await _decodeStack(archive, xmlElementImage.getElement(_oraElementStack), topFirst);
  return DecodedRasterDocument(
    size: _extractOraCanvasSize(xmlElementImage),
    layers: topFirst.reversed.toList(),
  );
}

/// Recursively decodes a stack node, appending its layers to [topFirst] in
/// document (top-first) order.
Future<void> _decodeStack(
  Archive archive,
  XmlElement? xmlStack,
  List<DecodedRasterLayer> topFirst,
) async {
  if (xmlStack == null) {
    return;
  }
  final String stackName = xmlStack.getAttribute(_oraAttrName) ?? '';
  for (final XmlElement xmlElementChild in xmlStack.childElements) {
    if (xmlElementChild.localName == _oraElementStack) {
      await _decodeStack(archive, xmlElementChild, topFirst);
    } else if (xmlElementChild.localName == _oraElementLayer) {
      topFirst.add(await _decodeLayer(archive, stackName, xmlElementChild));
    }
  }
}

/// Decodes one ORA layer node and its embedded PNG.
Future<DecodedRasterLayer> _decodeLayer(
  Archive archive,
  String stackName,
  XmlElement xmlLayer,
) async {
  final String opacityAsText = xmlLayer.getAttribute(_oraAttrOpacity) ?? '1';
  final String visibleAsText = xmlLayer.getAttribute(_oraAttrVisibility) ?? _oraVisibilityVisible;
  final String? src = xmlLayer.getAttribute(_oraAttrSrc);
  // Placement is only meaningful (and only parsed) for a layer with pixels.
  final ui.Offset offset = src == null
      ? ui.Offset.zero
      : ui.Offset(
          double.parse(xmlLayer.getAttribute(_oraAttrX) ?? '0'),
          double.parse(xmlLayer.getAttribute(_oraAttrY) ?? '0'),
        );

  // Blend mode and alpha preservation are only stored on layers with pixels;
  // an empty layer keeps the defaults.
  return DecodedRasterLayer(
    pixels: src == null ? null : await _decodeLayerPixels(archive, src),
    name: xmlLayer.getAttribute(_oraAttrName) ?? _oraUnnamedLayer,
    offset: offset,
    opacity: double.parse(opacityAsText),
    blendMode: src == null
        ? ui.BlendMode.srcOver
        : getBlendModeFromOraCompositOp(xmlLayer.getAttribute(_oraAttrCompositeOp) ?? _svgSrcOverLegacy),
    visible: _isLayerVisible(visibleAsText),
    locked: xmlLayer.getAttribute(_oraAttrEditLocked) == _booleanTextTrue,
    selected: xmlLayer.getAttribute(_oraAttrSelected) == _booleanTextTrue,
    parentGroupName: stackName,
    preserveAlpha: src == null || xmlLayer.getAttribute(_oraAttrAlphaPreserve) == _booleanTextTrue,
  );
}

/// Converts ORA visibility text into a layer-visible flag.
///
/// OpenRaster baseline uses "visible" and "hidden" while some legacy
/// documents may contain boolean text values. Unknown values default to
/// visible to match the ORA default visibility semantics.
bool _isLayerVisible(String visibilityAsText) {
  if (visibilityAsText == _oraVisibilityHidden || visibilityAsText == _booleanTextFalse) {
    return false;
  }

  if (visibilityAsText == _oraVisibilityVisible ||
      visibilityAsText == _booleanTextTrue ||
      visibilityAsText == _oraVisibilityInherit) {
    return true;
  }

  return true;
}

/// Returns a [ui.BlendMode] corresponding to the given OpenRaster (ORA)
/// composite operation string.
///
/// The function maps ORA composite operation strings (prefixed with "svg:")
/// to their respective [ui.BlendMode] values. If the provided composite
/// operation string does not match any known mapping, the default
/// [ui.BlendMode.srcOver] is returned.
///
ui.BlendMode getBlendModeFromOraCompositOp(String compositeOp) {
  return _oraCompositeOpBlendModes[compositeOp] ?? _oraLegacyCompositeOpBlendModes[compositeOp] ?? ui.BlendMode.srcOver;
}

/// Encodes a Flutter [ui.BlendMode] as an ORA `composite-op` value.
///
/// Modes ORA cannot express are written as `svg:source-over`.
String _getOraCompositeOpFromBlendMode(ui.BlendMode blendMode) {
  return _oraBlendModeCompositeOps[blendMode] ?? _svgSourceOver;
}

/// Decodes the archive entry [imageName] with the engine's image decoder.
///
/// A missing or undecodable entry is logged and yields null, so the layer
/// still opens (empty) rather than failing the whole document.
Future<DecodedLayerPixels?> _decodeLayerPixels(Archive archive, String imageName) async {
  try {
    final ArchiveFile? file = archive.files.toList().findFirstMatch((ArchiveFile f) => f.name == imageName);
    if (file == null) {
      _log.warning('$imageName not found in the archive');
      return null;
    }
    final List<int> bytes = file.content as List<int>;
    return UiImagePixels(await fromBytesToImage(bytes is Uint8List ? bytes : Uint8List.fromList(bytes)));
  } catch (e) {
    _log.severe('Failed to decode layer image', e);
    return null;
  }
}

/// Returns the embedded ORA preview PNG when the archive provides one.
///
/// This prefers the standard thumbnail entry, then falls back to the merged
/// preview image used by OpenRaster archives.
Future<Uint8List?> extractOraPreviewPngBytes(List<int> archiveBytes) async {
  try {
    final Archive archive = ZipDecoder().decodeBytes(archiveBytes);
    final ArchiveFile? previewFile = _findOraPreviewFile(archive);
    if (previewFile == null) {
      return null;
    }

    final Object content = previewFile.content;
    if (content is Uint8List) {
      return content;
    }
    if (content is List<int>) {
      return Uint8List.fromList(content);
    }
  } catch (e, stackTrace) {
    _log.warning('Failed to read ORA preview content', e, stackTrace);
    return null;
  }

  return null;
}

/// Finds the first standard OpenRaster preview asset present in [archive].
ArchiveFile? _findOraPreviewFile(Archive archive) {
  for (final String entryName in _oraPreviewEntries) {
    for (final ArchiveFile file in archive.files) {
      if (file.name == entryName) {
        return file;
      }
    }
  }

  return null;
}

/// Creates an ORA (OpenRaster) archive from the provided layers.
///
/// This function takes a [LayersProvider] object, which contains the layers
/// to be included in the ORA archive, and returns a `Future` that resolves
/// to a list of integers representing the binary data of the created archive.
///
/// ORA is a file format commonly used for storing layered images in a
/// non-proprietary format.
///
/// - Parameters:
///   - layers: A [LayersProvider] instance containing the layers to be
///     included in the ORA archive.
///   - includePreviews: When true, embeds merged and thumbnail preview PNGs.
///     Disable for internal snapshots when save latency is prioritized.
///
/// - Returns: A `Future` that resolves to a `List<int>` representing the
///   binary data of the created ORA archive.
Future<List<int>> createOraArchive(
  LayersProvider layers, {
  bool includePreviews = true,
}) async {
  final Archive archive = Archive();
  final XmlBuilder builder = XmlBuilder();

  // Add uncompressed mimetype
  archive.addFile(
    _storedNeutralArchiveFile(
      _oraMimetypeEntry,
      utf8.encode('image/openraster'),
    ),
  );

  // Placeholder for layer image names
  final List<Map<String, dynamic>> layersData = <Map<String, dynamic>>[];

  // Build XML metadata first so expensive layer rendering can run in batches.
  final List<_OraLayerExportRequest> exportRequests = <_OraLayerExportRequest>[];
  for (int i = 0; i < layers.length; i++) {
    final LayerProvider layer = layers.get(i);
    final Map<String, dynamic> layerData = <String, dynamic>{
      _oraLayerMetaParentGroupName: layer.parentGroupName,
      _oraAttrName: layer.name,
      _oraAttrVisibility: layer.isVisible ? _oraVisibilityVisible : _oraVisibilityHidden,
      _oraAttrOpacity: layer.opacity.toStringAsFixed(AppLimits.opacityPrecision),
      _oraAttrCompositeOp: _getOraCompositeOpFromBlendMode(layer.blendMode),
      _oraAttrEditLocked: layer.isLocked,
      _oraAttrSelected: i == layers.selectedLayerIndex,
    };

    if (_isOraLayerImageEmpty(layer)) {
      layersData.add(layerData);
      continue;
    }

    layersData.add(layerData);
    exportRequests.add(
      _OraLayerExportRequest(
        layerIndex: i,
        layer: layer,
      ),
    );
  }

  // Layers and previews share one memory-bounded pool and encode in
  // parallel; results are added in a fixed order so the archive stays
  // deterministic.
  final PngEncodePool pool = PngEncodePool(pixelBudget: PngEncodePool.platformPixelBudget);
  final Future<List<_OraLayerExportResult>> layerExports = Future.wait(
    exportRequests.map((_OraLayerExportRequest request) => _exportOraLayer(request, pool)),
  );
  final Future<List<ArchiveFile>> previewFiles = includePreviews
      ? _encodeOraPreviewFiles(layers: layers, pool: pool)
      : Future<List<ArchiveFile>>.value(<ArchiveFile>[]);
  final List<_OraLayerExportResult> exportResults = await layerExports;

  for (final _OraLayerExportResult result in exportResults) {
    archive.addFile(
      _storedNeutralArchiveFile(
        result.imageName,
        result.bytes,
      ),
    );

    final Map<String, dynamic> layerData = layersData[result.layerIndex];
    layerData[_oraAttrSrc] = result.imageName;
    layerData[_oraAttrX] = result.offset.dx.toInt();
    layerData[_oraAttrY] = result.offset.dy.toInt();
  }

  (await previewFiles).forEach(archive.addFile);

  // Create stack.xml synchronously
  builder.processing(_oraXmlProcessingTarget, _oraXmlEncoding);
  builder.element(
    _oraElementImage,
    nest: () {
      builder.attribute(_oraAttrVersion, '0.0.1');
      builder.attribute(
        _oraAttrWidth,
        layers.size.width.toInt().toString(),
      );
      builder.attribute(
        _oraAttrHeight,
        layers.size.height.toInt().toString(),
      );

      builder.element(
        _oraElementStack,
        nest: () {
          final Map<String, List<Map<String, dynamic>>> groupedLayers = <String, List<Map<String, dynamic>>>{};
          final List<Map<String, dynamic>> ungroupedLayers = <Map<String, dynamic>>[];

          for (final Map<String, dynamic> layerData in layersData) {
            final String parentGroupNameOfLayer = layerData[_oraLayerMetaParentGroupName] as String? ?? '';

            if (parentGroupNameOfLayer.isNotEmpty) {
              groupedLayers
                  .putIfAbsent(
                    parentGroupNameOfLayer,
                    () => <Map<String, dynamic>>[],
                  )
                  .add(layerData);
            } else {
              ungroupedLayers.add(layerData);
            }
          }

          for (final String groupName in groupedLayers.keys) {
            builder.element(
              _oraElementStack,
              nest: () {
                builder.attribute(_oraAttrName, groupName);
                buildLayers(builder, groupedLayers[groupName]!);
              },
            );
          }

          buildLayers(builder, ungroupedLayers);
        },
      );
    },
  );

  // Add stack.xml to the archive
  final String stackXml = builder.buildDocument().toString();
  archive.addFile(
    _neutralArchiveFile(
      _oraStackXmlEntry,
      utf8.encode(stackXml),
    ),
  );

  // Write archive to file
  final List<int> encodedData = ZipEncoder().encode(archive);

  return encodedData;
}

class _OraLayerExportRequest {
  _OraLayerExportRequest({
    required this.layerIndex,
    required this.layer,
  });

  final int layerIndex;
  final LayerProvider layer;
}

class _OraLayerExportResult {
  _OraLayerExportResult({
    required this.layerIndex,
    required this.imageName,
    required this.offset,
    required this.bytes,
  });

  final int layerIndex;
  final String imageName;
  final ui.Offset offset;
  final Uint8List bytes;
}

/// Exports one ORA layer image.
Future<_OraLayerExportResult> _exportOraLayer(_OraLayerExportRequest request, PngEncodePool pool) async {
  final ({Uint8List bytes, ui.Offset offset}) exportedLayer = await _prepareOraLayerExport(
    layer: request.layer,
    pool: pool,
  );

  return _OraLayerExportResult(
    layerIndex: request.layerIndex,
    imageName: '$_oraLayerImageEntryPrefix${request.layerIndex}$_oraLayerImageEntrySuffix',
    offset: exportedLayer.offset,
    bytes: exportedLayer.bytes,
  );
}

/// Empty layers can be represented in ORA XML without an image payload.
bool _isOraLayerImageEmpty(LayerProvider layer) {
  return layer.backgroundColor == null && layer.actionStack.isEmpty;
}

/// Encodes the standard merged and thumbnail preview PNGs, in archive order.
///
/// Previews are optional in ORA, so an encode failure skips them rather than
/// failing the save.
Future<List<ArchiveFile>> _encodeOraPreviewFiles({
  required LayersProvider layers,
  required PngEncodePool pool,
}) async {
  // Owned by the provider (layers.cachedImage): never dispose it here.
  final ui.Image mergedImage = await layers.captureCompositeForExport();
  final ui.Image thumbnailImage = _createOraThumbnailImage(mergedImage);
  final List<Uint8List?> encoded = await Future.wait(<Future<Uint8List?>>[
    pool.run(mergedImage.width * mergedImage.height, () => _safeImageToPngBytes(mergedImage, _oraMergedImageEntry)),
    _safeImageToPngBytes(thumbnailImage, _oraThumbnailEntry, dispose: true),
  ]);
  final Uint8List? mergedPngBytes = encoded.first;
  final Uint8List? thumbnailPngBytes = encoded.last;
  if (mergedPngBytes == null) {
    return <ArchiveFile>[];
  }
  return <ArchiveFile>[
    _storedNeutralArchiveFile(_oraMergedImageEntry, mergedPngBytes),
    if (thumbnailPngBytes != null) _storedNeutralArchiveFile(_oraThumbnailEntry, thumbnailPngBytes),
  ];
}

/// Converts [image] to PNG bytes while tolerating transient engine failures,
/// disposing it afterwards when [dispose] is set.
///
/// Some test runs can hit an engine assertion inside [ui.Image.toByteData]
/// under heavy image churn. In that case previews are skipped, while the ORA
/// layer payload remains valid.
Future<Uint8List?> _safeImageToPngBytes(ui.Image image, String entryName, {bool dispose = false}) async {
  try {
    return await encodeImageToPngFast(image, disposeAfterReadback: dispose);
  } on Object catch (error, stackTrace) {
    _log.warning('Skipping ORA preview entry "$entryName" due to PNG encode failure.', error, stackTrace);
    return null;
  }
}

/// Builds the ORA thumbnail directly from the merged image without a PNG round-trip.
ui.Image _createOraThumbnailImage(ui.Image mergedImage) {
  final int targetHeight = math.max(AppLayout.thumbnailMaxHeight.toInt(), AppMath.one);
  final double scale = targetHeight / mergedImage.height;
  final int targetWidth = math.max((mergedImage.width * scale).round(), AppMath.one);

  return renderCanvasImageSync(
    width: targetWidth,
    height: targetHeight,
    draw: (ui.Canvas canvas) {
      canvas.drawImageRect(
        mergedImage,
        ui.Rect.fromLTWH(
          AppMath.zero.toDouble(),
          AppMath.zero.toDouble(),
          mergedImage.width.toDouble(),
          mergedImage.height.toDouble(),
        ),
        ui.Rect.fromLTWH(
          AppMath.zero.toDouble(),
          AppMath.zero.toDouble(),
          targetWidth.toDouble(),
          targetHeight.toDouble(),
        ),
        ui.Paint(),
      );
    },
  );
}

/// Builds the layers for the specified file or canvas.
///
/// This function is responsible for constructing and organizing
/// the layers that make up the structure of the file or canvas.
/// It may involve parsing data, initializing layer properties,
/// and ensuring the correct hierarchy of layers.
///
/// Make sure to provide the necessary input data or context
/// required for the layer construction process.
void buildLayers(
  XmlBuilder builder,
  List<Map<String, dynamic>> layersData,
) {
  for (final Map<String, dynamic> layerData in layersData) {
    final String? compositeOp = layerData[_oraAttrCompositeOp] as String?;
    final bool isLocked = layerData[_oraAttrEditLocked] as bool? ?? false;
    final bool isSelected = layerData[_oraAttrSelected] as bool? ?? false;

    builder.element(
      _oraElementLayer,
      nest: () {
        builder.attribute(_oraAttrName, layerData[_oraAttrName]);
        builder.attribute(_oraAttrVisibility, layerData[_oraAttrVisibility]);
        builder.attribute(_oraAttrOpacity, layerData[_oraAttrOpacity]);
        if (compositeOp != null) {
          builder.attribute(_oraAttrCompositeOp, compositeOp);
        }
        if (isLocked) {
          builder.attribute(_oraAttrEditLocked, _booleanTextTrue);
        }
        if (isSelected) {
          builder.attribute(_oraAttrSelected, _booleanTextTrue);
        }
        builder.attribute(_oraAttrSrc, layerData[_oraAttrSrc]);
        builder.attribute(_oraAttrX, layerData[_oraAttrX]);
        builder.attribute(_oraAttrY, layerData[_oraAttrY]);
      },
    );
  }
}
