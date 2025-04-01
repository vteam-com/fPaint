import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:xml/xml.dart';

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
  try {
    final File oraFile = File(filePath);
    if (!await oraFile.exists()) {
      throw Exception('File not found "$filePath"');
    }

    // Read the file as bytes
    await readOraFileFromBytes(
      layers,
      await oraFile.readAsBytes(),
    );
  } catch (e) {
    throw Exception('Failed to read ORA file: $e');
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
      (final ArchiveFile file) => file.name == 'stack.xml',
      orElse: () => throw Exception('stack.xml not found in ORA file'),
    );

    // Parse the stack.xml content
    final XmlDocument xmlDoc = XmlDocument.parse(
      String.fromCharCodes(stackFile.content),
    );

    // print(xmlDoc.toString());

    await importFromOraXml(archive, layers, xmlDoc);
  } catch (error) {
    throw Exception('Failed to read ORA file: $error');
  }
}

Future<void> importFromOraXml(
  final Archive archive,
  final LayersProvider layers,
  final XmlDocument xmlDoc,
) async {
  final XmlElement? xmlElementImage = xmlDoc.getElement('image');
  layers.size = ui.Size(
    double.parse(xmlElementImage!.getAttribute('w')!),
    double.parse(xmlElementImage.getAttribute('h')!),
  );

  final XmlElement? xmlElementTopStack = xmlElementImage.getElement('stack');
  await importStack(archive, layers, xmlElementTopStack);
}

Future<void> importStack(
  final Archive archive,
  final LayersProvider layers,
  final XmlElement? xmlElementTopStack,
) async {
  if (xmlElementTopStack != null) {
    final String stackName = xmlElementTopStack.getAttribute('name') ?? '';
    for (final XmlElement xmlElementchild in xmlElementTopStack.childElements) {
      if (xmlElementchild.localName == 'stack') {
        await importStack(archive, layers, xmlElementchild);
      } else {
        if (xmlElementchild.localName == 'layer') {
          await addLayer(archive, layers, stackName, xmlElementchild);
        }
      }
    }
  }
}

Future<void> addLayer(
  final Archive archive,
  final LayersProvider layers,
  final String stackName,
  final XmlElement xmlLayer,
) async {
  final String name = xmlLayer.getAttribute('name') ?? 'Unnamed';
  final String opacityAsText = xmlLayer.getAttribute('opacity') ?? '1';
  final String visibleAsText = xmlLayer.getAttribute('visible') ?? 'true';
  final String compositeOp =
      xmlLayer.getAttribute('composite-op') ?? 'svg:src-over';

  final bool preserveAlpha = xmlLayer.getAttribute('alpha-preserve') == 'true';

  final LayerProvider newLayer = layers.addBottom(name);
  newLayer.parentGroupName = stackName;
  newLayer.isVisible = visibleAsText == 'true';
  newLayer.opacity = double.parse(opacityAsText);

  // is there an image on this layer?
  final String? src = xmlLayer.getAttribute('src');
  if (src != null) {
    final String? xAsText = xmlLayer.getAttribute('x');
    final String? yAsText = xmlLayer.getAttribute('y');

    final ui.Offset offset = ui.Offset(
      double.parse(xAsText ?? '0'),
      double.parse(yAsText ?? '0'),
    );

    newLayer.blendMode = getBlendModeFromOraCompositOp(compositeOp);
    newLayer.preserveAlpha = preserveAlpha;

    await addImageToLayer(
      archive: archive,
      layers: layers,
      layer: newLayer,
      imageName: src,
      offset: offset,
    );
  }
  return;
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
    case 'svg:source-over':
      return ui.BlendMode.srcOver;
    case 'svg:multiply':
      return ui.BlendMode.multiply;
    case 'svg:screen':
      return ui.BlendMode.screen;
    case 'svg:overlay':
      return ui.BlendMode.overlay;
    case 'svg:darken':
      return ui.BlendMode.darken;
    case 'svg:lighten':
      return ui.BlendMode.lighten;
    case 'svg:color-dodge':
      return ui.BlendMode.colorDodge;
    case 'svg:color-burn':
      return ui.BlendMode.colorBurn;
    case 'svg:hard-light':
      return ui.BlendMode.hardLight;
    case 'svg:soft-light':
      return ui.BlendMode.softLight;
    case 'svg:difference':
      return ui.BlendMode.difference;
    case 'svg:exclusion':
      return ui.BlendMode.exclusion;
    default:
      return ui.BlendMode.srcOver;
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
  required final LayersProvider layers,
  required final LayerProvider layer,
  required final String imageName,
  required final ui.Offset offset,
}) async {
  try {
    final ArchiveFile? file = archive.files
        .toList()
        .findFirstMatch((final ArchiveFile f) => f.name == imageName);
    if (file != null) {
      final List<int> bytes = file.content as List<int>;
      final ui.Image image = await decodeImage(bytes);

      layer.addImage(
        imageToAdd: image,
        offset: offset,
      );
    } else {
      debugPrint('$imageName not found in the achive');
    }
  } catch (e) {
    debugPrint(e.toString());
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
/// - This function does not throw errors but logs them using [debugPrint].
///
/// Example:
/// ```dart
/// await addImageToLayer(
///   archive: myArchive,
///   layers: myLayersProvider,
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

///
/// Persist to ORA type file
///
Future<void> saveToORA({
  required final LayersProvider layers,
  required final String filePath,
}) async {
  final List<int> encodedData = await createOraAchive(layers);

  await File(filePath).writeAsBytes(encodedData);
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
Future<List<int>> createOraAchive(final LayersProvider layers) async {
  final Archive archive = Archive();
  final XmlBuilder builder = XmlBuilder();

  // Add uncompressed mimetype
  archive.addFile(
    ArchiveFile(
      'mimetype',
      'image/openraster'.length,
      utf8.encode('image/openraster'),
    ),
  );

  // Placeholder for layer image names
  final List<Map<String, dynamic>> layersData = <Map<String, dynamic>>[];

  // Generate PNG files and add them to the archive
  for (int i = 0; i < layers.length; i++) {
    final LayerProvider layer = layers.get(i);
    final String imageName = 'data/layer-$i.png';

    // Save layer image as PNG
    final ui.Image imageLayer = layer.toImageForStorage(layers.size);

    final ByteData? bytes =
        await imageLayer.toByteData(format: ui.ImageByteFormat.png);

    archive.addFile(
      ArchiveFile(
        imageName,
        bytes!.lengthInBytes,
        bytes.buffer.asUint8List(),
      ),
    );

    layersData.add(<String, dynamic>{
      'parentGroupName': layer.parentGroupName,
      'name': layer.name,
      'visibility': layer.isVisible ? 'visible' : 'hidden',
      'opacity': layer.opacity.toStringAsFixed(5),
      'src': imageName,
      'x': 0,
      'y': 0,
    });
  }

  // Create stack.xml synchronously
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element(
    'image',
    nest: () {
      builder.attribute('version', '0.0.1');
      builder.attribute(
        'w',
        layers.size.width.toInt().toString(),
      );
      builder.attribute(
        'h',
        layers.size.height.toInt().toString(),
      );

      builder.element(
        'stack',
        nest: () {
          final Map<String, List<Map<String, dynamic>>> groupedLayers =
              <String, List<Map<String, dynamic>>>{};
          final List<Map<String, dynamic>> ungroupedLayers =
              <Map<String, dynamic>>[];

          for (final Map<String, dynamic> layerData in layersData) {
            final String parentGroupNameOfLayer =
                layerData['parentGroupName'] as String? ?? '';

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
              'stack',
              nest: () {
                builder.attribute('name', groupName);
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
    ArchiveFile(
      'stack.xml',
      stackXml.length,
      utf8.encode(stackXml),
    ),
  );

  // Write archive to file
  final List<int> encodedData = ZipEncoder().encode(archive);
  return encodedData;
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
    builder.element(
      'layer',
      nest: () {
        builder.attribute('name', layerData['name']);
        builder.attribute('visibility', layerData['visibility']);
        builder.attribute('opacity', layerData['opacity']);
        builder.attribute('src', layerData['src']);
        builder.attribute('x', layerData['x']);
        builder.attribute('y', layerData['y']);
      },
    );
  }
}
