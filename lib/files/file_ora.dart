import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:xml/xml.dart';

/// Reads an ORA file and updates the provided [AppModel] with its contents.
///
/// This function asynchronously reads the ORA file located at the given [filePath]
/// and updates the [appModel] with the data extracted from the file.
///
/// - Parameters:
///   - appModel: The application model to be updated with the ORA file's contents.
///   - filePath: The path to the ORA file to be read.
///
/// - Returns: A [Future] that completes when the file has been read and the model updated.
Future<void> readOraFile(final AppModel appModel, String filePath) async {
  try {
    final File oraFile = File(filePath);
    if (!await oraFile.exists()) {
      debugPrint('File not found: $filePath');
      return;
    }

    appModel.loadedFileName = filePath;

    // Read the file as bytes
    await readOraFileFromBytes(
      appModel,
      await oraFile.readAsBytes(),
    );
  } catch (e) {
    throw Exception('Failed to read ORA file: $e');
  }
}

/// Read the file from  bytes
Future<void> readOraFileFromBytes(
  AppModel appModel,
  Uint8List bytes,
) async {
  // Extract the ZIP contents
  final Archive archive = ZipDecoder().decodeBytes(bytes);

  // Find the stack.xml file
  final ArchiveFile stackFile = archive.files.firstWhere(
    (file) => file.name == 'stack.xml',
    orElse: () => throw Exception('stack.xml not found in ORA file'),
  );

  // Parse the stack.xml content
  final XmlDocument stackXml = XmlDocument.parse(
    String.fromCharCodes(stackFile.content),
  );

  //print(stackXml.toString());

  final XmlElement? rootImage = stackXml.getElement('image');
  appModel.canvasModel.canvasSize = ui.Size(
    double.parse(rootImage!.getAttribute('w')!),
    double.parse(rootImage.getAttribute('h')!),
  );

  // Extract layers
  for (final XmlElement xmlLayer in stackXml.findAllElements('layer')) {
    final String name = xmlLayer.getAttribute('name') ?? 'Unnamed';
    final String opacityAsText = xmlLayer.getAttribute('opacity') ?? '1';
    final String visibleAsText = xmlLayer.getAttribute('visible') ?? 'true';
    final String compositeOp =
        xmlLayer.getAttribute('composite-op') ?? 'svg:src-over';

    final bool preserveAlpha =
        xmlLayer.getAttribute('alpha-preserve') == 'true';

    final Layer newLayer = appModel.addLayerBottom(name);
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
        appModel: appModel,
        layer: newLayer,
        archive: archive,
        imageName: src,
        offset: offset,
      );
    }
  }
}

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

///
Future<void> addImageToLayer({
  required final Archive archive,
  required final AppModel appModel,
  required final Layer layer,
  required final String imageName,
  required final ui.Offset offset,
}) async {
  try {
    final ArchiveFile? file =
        archive.files.toList().findFirstMatch((f) => f.name == imageName);
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

/// Decodes a list of bytes into a [ui.Image].
///
/// This function takes a list of bytes representing an image and decodes it
/// into a [ui.Image] object asynchronously.
///
/// - Parameters:
///   - bytes: A list of integers representing the image data.
///
/// - Returns: A [Future] that completes with the decoded [ui.Image].
///
/// Example:
/// ```dart
/// List<int> imageData = ...; // your image data here
/// ui.Image image = await decodeImage(imageData);
/// ```
Future<ui.Image> decodeImage(List<int> bytes) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(Uint8List.fromList(bytes), completer.complete);
  return completer.future;
}

///
Future<void> saveToORA({
  required final AppModel appModel,
  required final String filePath,
}) async {
  List<int> encodedData = await createOraAchive(appModel);

  await File(filePath).writeAsBytes(encodedData);
}

///
Future<List<int>> createOraAchive(AppModel appModel) async {
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
  final List<Map<String, dynamic>> layersData = [];

  // Generate PNG files and add them to the archive
  for (int i = 0; i < appModel.layers.length; i++) {
    final Layer layer = appModel.layers.get(i);
    final String imageName = 'data/layer-$i.png';

    // Save layer image as PNG
    final ui.Image imageLayer =
        await layer.toImageForStorage(appModel.canvasModel.canvasSize);

    final ByteData? bytes =
        await imageLayer.toByteData(format: ui.ImageByteFormat.png);

    archive.addFile(
      ArchiveFile(
        imageName,
        bytes!.lengthInBytes,
        bytes.buffer.asUint8List(),
      ),
    );

    layersData.add({
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
        appModel.canvasModel.canvasSize.width.toInt().toString(),
      );
      builder.attribute(
        'h',
        appModel.canvasModel.canvasSize.height.toInt().toString(),
      );

      builder.element(
        'stack',
        nest: () {
          for (final layerData in layersData) {
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
