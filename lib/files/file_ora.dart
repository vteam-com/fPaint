import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/layer_provider_storage_export.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

final Logger _log = Logger(logNameFileOra);

// ORA file format element and attribute identifiers
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
const String _errorOraFileNotFoundPrefix = 'ORA file not found:';
const String _errorOraReadFilePrefix = 'Failed to read ORA file:';
const String _errorOraReadBytes = 'Failed to read ORA bytes.';
const String _errorOraMissingStackXml = 'stack.xml not found in ORA file.';
const String _errorOraMissingImageElement = 'image element not found in ORA stack.xml.';
const String _errorOraMissingDimensions = 'ORA image dimensions are missing.';
const String _errorOraLayerEncodingFailed = 'Failed to encode ORA layer PNG.';

const List<String> _oraPreviewEntries = <String>[
  _oraThumbnailEntry,
  _oraThumbnailEntryLowercase,
  _oraMergedImageEntry,
];

/// Creates an [ArchiveFile] with a fixed timestamp so archives are
/// byte-identical across runs when the payload has not changed.
ArchiveFile _neutralArchiveFile(final String name, final List<int> data) {
  final ArchiveFile file = ArchiveFile.bytes(name, data);
  file.lastModTime = 0;
  return file;
}

/// Creates a deterministic [ArchiveFile] stored without ZIP recompression.
ArchiveFile _storedNeutralArchiveFile(final String name, final List<int> data) {
  final ArchiveFile file = _neutralArchiveFile(name, data);
  file.compression = CompressionType.none;
  return file;
}

/// Renders [layer], crops away transparent margins, and returns PNG bytes plus
/// the cropped image's original canvas offset for ORA `x`/`y` metadata.
Future<({Uint8List bytes, ui.Offset offset})> _prepareOraLayerExport({
  required final LayerProvider layer,
}) async {
  final ui.Rect exportBounds = layer.estimateContentBoundsForStorage();
  final ui.Image layerImage = layer.toImageForStorageBounds(exportBounds);
  try {
    final ByteData? byteData = await layerImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw const OraFileException(_errorOraLayerEncodingFailed);
    }

    return (
      bytes: byteData.buffer.asUint8List(),
      offset: exportBounds.topLeft,
    );
  } finally {
    layerImage.dispose();
  }
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

/// Reads an ORA file and updates the provided [AppProvider] with its contents.
///
/// This function asynchronously reads the ORA file located at the given [filePath]
/// and updates the [shellProvider] with the data extracted from the file.
///
/// - Parameters:
///   - appProvider: The application model to be updated with the ORA file's contents.
///   - filePath: The path to the ORA file to be read.
///
/// - Returns: A [Future] that completes when the file has been read and the model updated.
Future<void> readImageFromFilePathOra(
  final LayersProvider layers,
  final String filePath,
) async {
  final File oraFile = File(filePath);
  if (!await oraFile.exists()) {
    throw OraFileException('$_errorOraFileNotFoundPrefix "$filePath"');
  }

  try {
    await readOraFileFromBytes(
      layers,
      await oraFile.readAsBytes(),
    );
  } on OraFileException {
    rethrow;
  } catch (error, stackTrace) {
    throwFileOperationException<OraFileException>(
      message: '$_errorOraReadFilePrefix "$filePath"',
      error: error,
      stackTrace: stackTrace,
      exceptionBuilder: OraFileException.new,
    );
  }
}

/// Read the file from  bytes
Future<void> readOraFileFromBytes(
  final LayersProvider layers,
  final Uint8List bytes,
) async {
  try {
    // Extract the ZIP contents
    final Archive archive = ZipDecoder().decodeBytes(bytes);

    // Find the stack.xml file
    final ArchiveFile stackFile = archive.files.firstWhere(
      (final ArchiveFile file) => file.name == _oraStackXmlEntry,
      orElse: () => throw const OraFileException(_errorOraMissingStackXml),
    );

    // Parse the stack.xml content
    final XmlDocument xmlDoc = XmlDocument.parse(
      String.fromCharCodes(stackFile.content),
    );

    final ui.Size canvasSize = _extractOraCanvasSize(xmlDoc);

    await layers.replaceAll(
      canvasSize: canvasSize,
      addLayers: () => importFromOraXml(archive, layers, xmlDoc),
    );
  } on OraFileException {
    rethrow;
  } catch (error, stackTrace) {
    throwFileOperationException<OraFileException>(
      message: _errorOraReadBytes,
      error: error,
      stackTrace: stackTrace,
      exceptionBuilder: OraFileException.new,
    );
  }
}

/// Extracts the canvas size from the ORA XML document.
ui.Size _extractOraCanvasSize(final XmlDocument xmlDoc) {
  final XmlElement? xmlElementImage = xmlDoc.getElement(_oraElementImage);
  if (xmlElementImage == null) {
    throw const OraFileException(_errorOraMissingImageElement);
  }

  final String? width = xmlElementImage.getAttribute(_oraAttrWidth);
  final String? height = xmlElementImage.getAttribute(_oraAttrHeight);
  if (width == null || height == null) {
    throw const OraFileException(_errorOraMissingDimensions);
  }

  return ui.Size(double.parse(width), double.parse(height));
}

/// Imports image metadata and root stack information from an ORA XML document.
Future<void> importFromOraXml(
  final Archive archive,
  final LayersProvider layers,
  final XmlDocument xmlDoc,
) async {
  final XmlElement? xmlElementImage = xmlDoc.getElement(_oraElementImage);
  if (xmlElementImage == null) {
    throw const OraFileException(_errorOraMissingImageElement);
  }

  final String? width = xmlElementImage.getAttribute(_oraAttrWidth);
  final String? height = xmlElementImage.getAttribute(_oraAttrHeight);
  if (width == null || height == null) {
    throw const OraFileException(_errorOraMissingDimensions);
  }

  layers.size = ui.Size(
    double.parse(width),
    double.parse(height),
  );

  final XmlElement? xmlElementTopStack = xmlElementImage.getElement(_oraElementStack);
  await importStack(archive, layers, xmlElementTopStack);
}

/// Recursively imports a stack node and its child stacks and layers.
Future<void> importStack(
  final Archive archive,
  final LayersProvider layers,
  final XmlElement? xmlElementTopStack,
) async {
  if (xmlElementTopStack != null) {
    final String stackName = xmlElementTopStack.getAttribute(_oraAttrName) ?? '';
    for (final XmlElement xmlElementChild in xmlElementTopStack.childElements) {
      if (xmlElementChild.localName == _oraElementStack) {
        await importStack(archive, layers, xmlElementChild);
      } else {
        if (xmlElementChild.localName == _oraElementLayer) {
          await addLayer(archive, layers, stackName, xmlElementChild);
        }
      }
    }
  }
}

/// Creates and configures a layer from an ORA layer XML node.
Future<void> addLayer(
  final Archive archive,
  final LayersProvider layers,
  final String stackName,
  final XmlElement xmlLayer,
) async {
  final String name = xmlLayer.getAttribute(_oraAttrName) ?? 'Unnamed';
  final String opacityAsText = xmlLayer.getAttribute(_oraAttrOpacity) ?? '1';
  final String visibleAsText = xmlLayer.getAttribute(_oraAttrVisibility) ?? _oraVisibilityVisible;
  final String compositeOp = xmlLayer.getAttribute(_oraAttrCompositeOp) ?? _svgSrcOverLegacy;

  final bool preserveAlpha = xmlLayer.getAttribute(_oraAttrAlphaPreserve) == _booleanTextTrue;
  final bool isLocked = xmlLayer.getAttribute(_oraAttrEditLocked) == _booleanTextTrue;

  final LayerProvider newLayer = layers.addBottom(name);
  newLayer.parentGroupName = stackName;
  newLayer.isVisible = _isLayerVisible(visibleAsText);
  newLayer.isLocked = isLocked;
  newLayer.opacity = double.parse(opacityAsText);

  // is there an image on this layer?
  final String? src = xmlLayer.getAttribute(_oraAttrSrc);
  if (src != null) {
    final String? xAsText = xmlLayer.getAttribute(_oraAttrX);
    final String? yAsText = xmlLayer.getAttribute(_oraAttrY);

    final ui.Offset offset = ui.Offset(
      double.parse(xAsText ?? '0'),
      double.parse(yAsText ?? '0'),
    );

    newLayer.blendMode = getBlendModeFromOraCompositOp(compositeOp);
    newLayer.preserveAlpha = preserveAlpha;

    await addImageToLayer(
      archive: archive,
      layer: newLayer,
      imageName: src,
      offset: offset,
    );
  }
  return;
}

/// Converts ORA visibility text into a layer-visible flag.
///
/// OpenRaster baseline uses "visible" and "hidden" while some legacy
/// documents may contain boolean text values. Unknown values default to
/// visible to match the ORA default visibility semantics.
bool _isLayerVisible(final String visibilityAsText) {
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
ui.BlendMode getBlendModeFromOraCompositOp(final String compositeOp) {
  switch (compositeOp) {
    case _svgSourceOver:
    case _svgSrcOverLegacy:
      return ui.BlendMode.srcOver;
    case _svgMultiply:
      return ui.BlendMode.multiply;
    case _svgScreen:
      return ui.BlendMode.screen;
    case _svgOverlay:
      return ui.BlendMode.overlay;
    case _svgDarken:
      return ui.BlendMode.darken;
    case _svgLighten:
      return ui.BlendMode.lighten;
    case _svgColorDodge:
      return ui.BlendMode.colorDodge;
    case _svgColorBurn:
      return ui.BlendMode.colorBurn;
    case _svgHardLight:
      return ui.BlendMode.hardLight;
    case _svgSoftLight:
      return ui.BlendMode.softLight;
    case _svgDifference:
      return ui.BlendMode.difference;
    case _svgExclusion:
      return ui.BlendMode.exclusion;
    case _svgPlus:
      return ui.BlendMode.plus;
    case _svgHue:
      return ui.BlendMode.hue;
    case _svgSaturation:
      return ui.BlendMode.saturation;
    case _svgColor:
      return ui.BlendMode.color;
    case _svgLuminosity:
      return ui.BlendMode.luminosity;
    default:
      return ui.BlendMode.srcOver;
  }
}

/// Encodes a Flutter [ui.BlendMode] as an ORA `composite-op` value.
String _getOraCompositeOpFromBlendMode(final ui.BlendMode blendMode) {
  switch (blendMode) {
    case ui.BlendMode.srcOver:
      return _svgSourceOver;
    case ui.BlendMode.multiply:
      return _svgMultiply;
    case ui.BlendMode.screen:
      return _svgScreen;
    case ui.BlendMode.overlay:
      return _svgOverlay;
    case ui.BlendMode.darken:
      return _svgDarken;
    case ui.BlendMode.lighten:
      return _svgLighten;
    case ui.BlendMode.colorDodge:
      return _svgColorDodge;
    case ui.BlendMode.colorBurn:
      return _svgColorBurn;
    case ui.BlendMode.hardLight:
      return _svgHardLight;
    case ui.BlendMode.softLight:
      return _svgSoftLight;
    case ui.BlendMode.difference:
      return _svgDifference;
    case ui.BlendMode.exclusion:
      return _svgExclusion;
    case ui.BlendMode.plus:
      return _svgPlus;
    case ui.BlendMode.hue:
      return _svgHue;
    case ui.BlendMode.saturation:
      return _svgSaturation;
    case ui.BlendMode.color:
      return _svgColor;
    case ui.BlendMode.luminosity:
      return _svgLuminosity;
    default:
      return _svgSourceOver;
  }
}

/// Adds an image to a specified layer from an archive.
///
/// This function retrieves an image file from the provided [archive] using the
/// specified [imageName]. If the image is found, it decodes the image bytes
/// into a [ui.Image] and adds it to the given [layer] at the specified [offset].
///
/// If the image is not found in the archive, a debug message is printed.
/// Any errors during the process are caught and logged.
Future<void> addImageToLayer({
  required final Archive archive,
  required final LayerProvider layer,
  required final String imageName,
  required final ui.Offset offset,
}) async {
  try {
    final ArchiveFile? file = archive.files.toList().findFirstMatch((final ArchiveFile f) => f.name == imageName);
    if (file != null) {
      final List<int> bytes = file.content as List<int>;
      final ui.Image image = await decodeImage(bytes);

      layer.addImage(
        imageToAdd: image,
        offset: offset,
      );
    } else {
      _log.warning('$imageName not found in the archive');
    }
  } catch (e) {
    _log.severe('Failed to add image to layer', e);
  }
}

///
/// Parameters:
/// - [archive]: The archive containing the image files.
/// - [layers]: The provider managing all layers (not directly used in this function).
/// - [layer]: The specific layer to which the image will be added.
/// - [imageName]: The name of the image file to retrieve from the archive.
/// - [offset]: The position where the image will be added on the layer.
///
/// Throws:
/// - This function does not throw errors but logs them using [Logger].
///
/// Example:
/// ```dart
/// await addImageToLayer(
///   archive: myArchive,
///   layer: myLayerProvider,
///   imageName: 'example.png',
///   offset: ui.Offset(10, 20),
/// );
/// ```

Future<ui.Image> decodeImage(final List<int> bytes) async {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromList(Uint8List.fromList(bytes), completer.complete);
  return completer.future;
}

/// Returns the embedded ORA preview PNG when the archive provides one.
///
/// This prefers the standard thumbnail entry, then falls back to the merged
/// preview image used by OpenRaster archives.
Future<Uint8List?> extractOraPreviewPngBytes(final List<int> archiveBytes) async {
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
  } catch (_) {
    return null;
  }

  return null;
}

/// Finds the first standard OpenRaster preview asset present in [archive].
ArchiveFile? _findOraPreviewFile(final Archive archive) {
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
///
/// - Returns: A `Future` that resolves to a `List<int>` representing the
///   binary data of the created ORA archive.
Future<List<int>> createOraArchive(final LayersProvider layers) async {
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

  // Generate PNG files and add them to the archive
  for (int i = 0; i < layers.length; i++) {
    final LayerProvider layer = layers.get(i);
    final String imageName = 'data/layer-$i.png';
    final ({Uint8List bytes, ui.Offset offset}) exportedLayer = await _prepareOraLayerExport(
      layer: layer,
    );

    archive.addFile(
      _storedNeutralArchiveFile(
        imageName,
        exportedLayer.bytes,
      ),
    );

    layersData.add(<String, dynamic>{
      'parentGroupName': layer.parentGroupName,
      _oraAttrName: layer.name,
      _oraAttrVisibility: layer.isVisible ? _oraVisibilityVisible : _oraVisibilityHidden,
      _oraAttrOpacity: layer.opacity.toStringAsFixed(AppLimits.opacityPrecision),
      _oraAttrCompositeOp: _getOraCompositeOpFromBlendMode(layer.blendMode),
      _oraAttrEditLocked: layer.isLocked,
      _oraAttrSrc: imageName,
      _oraAttrX: exportedLayer.offset.dx.toInt(),
      _oraAttrY: exportedLayer.offset.dy.toInt(),
    });
  }

  await _addOraPreviewFiles(archive: archive, layers: layers);

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
            final String parentGroupNameOfLayer = layerData['parentGroupName'] as String? ?? '';

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

/// Writes standard merged and thumbnail preview PNGs into the ORA [archive].
Future<void> _addOraPreviewFiles({
  required final Archive archive,
  required final LayersProvider layers,
}) async {
  final ui.Image mergedImage = await layers.capturePainterToImage();
  final ByteData? mergedPngData = await mergedImage.toByteData(format: ui.ImageByteFormat.png);
  if (mergedPngData == null) {
    return;
  }

  final Uint8List mergedPngBytes = mergedPngData.buffer.asUint8List();
  archive.addFile(
    _storedNeutralArchiveFile(
      _oraMergedImageEntry,
      mergedPngBytes,
    ),
  );

  final ui.Codec thumbnailCodec = await ui.instantiateImageCodec(
    mergedPngBytes,
    targetHeight: AppLayout.thumbnailMaxHeight.toInt(),
  );
  try {
    final ui.FrameInfo thumbnailFrame = await thumbnailCodec.getNextFrame();
    try {
      final ByteData? thumbnailPngData = await thumbnailFrame.image.toByteData(format: ui.ImageByteFormat.png);
      if (thumbnailPngData == null) {
        return;
      }

      archive.addFile(
        _storedNeutralArchiveFile(
          _oraThumbnailEntry,
          thumbnailPngData.buffer.asUint8List(),
        ),
      );
    } finally {
      thumbnailFrame.image.dispose();
    }
  } finally {
    thumbnailCodec.dispose();
  }
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
  final XmlBuilder builder,
  final List<Map<String, dynamic>> layersData,
) {
  for (final Map<String, dynamic> layerData in layersData) {
    final String? compositeOp = layerData[_oraAttrCompositeOp] as String?;
    final bool isLocked = layerData[_oraAttrEditLocked] as bool? ?? false;

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
        builder.attribute(_oraAttrSrc, layerData[_oraAttrSrc]);
        builder.attribute(_oraAttrX, layerData[_oraAttrX]);
        builder.attribute(_oraAttrY, layerData[_oraAttrY]);
      },
    );
  }
}
