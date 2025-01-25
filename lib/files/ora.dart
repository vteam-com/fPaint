import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:xml/xml.dart';

// Load the ORA file
Future<void> readOraFile(final AppModel appModel, String filePath) async {
  try {
    final File oraFile = File(filePath);
    if (!await oraFile.exists()) {
      print('File not found: $filePath');
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

// Read the file from  bytes
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
  appModel.canvasSize = ui.Size(
    double.parse(rootImage!.getAttribute('w')!),
    double.parse(rootImage.getAttribute('h')!),
  );

  // Extract layers
  for (final XmlElement xmlLayer in stackXml.findAllElements('layer')) {
    final String name = xmlLayer.getAttribute('name') ?? 'Unnamed';
    final String opacityAsText = xmlLayer.getAttribute('opacity') ?? '1.0';
    final String visibleAsText = xmlLayer.getAttribute('visible') ?? 'true';

    final PaintLayer newLayer = appModel.addLayerBottom(name);
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

      await addImageToLayer(
        appModel: appModel,
        layer: newLayer,
        archive: archive,
        imageName: src,
        offset: offset,
      );
    }

    // print(
    //   'Layer:"$name" opacity:$opacityAsText visible:$visibleAsText',
    // );
  }
}

Future<void> addImageToLayer({
  required final Archive archive,
  required final AppModel appModel,
  required final PaintLayer layer,
  required final String imageName,
  required final ui.Offset offset,
}) async {
  try {
    final ArchiveFile? file =
        archive.files.toList().findFirstMatch((f) => f.name == imageName);
    if (file != null) {
      final List<int> bytes = file.content as List<int>;
      final ui.Image image = await decodeImage(bytes);

      layer.addImage(image, offset);
    } else {
      print('$imageName not found in the achive');
    }
  } catch (e) {
    print(e.toString());
  }
}

Future<ui.Image> decodeImage(List<int> bytes) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(Uint8List.fromList(bytes), completer.complete);
  return completer.future;
}

Future<void> saveToORA({
  required final AppModel appModel,
  required final String filePath,
}) async {
  List<int> encodedData = await createOraAchive(appModel);

  await File(filePath).writeAsBytes(encodedData);
}

Future<List<int>> createOraAchive(AppModel appModel) async {
  final Archive archive = Archive();
  final XmlBuilder builder = XmlBuilder();

  // Add uncompressed mimetype
  archive.addFile(
    ArchiveFile.noCompress(
      'mimetype',
      'image/openraster'.length,
      utf8.encode('image/openraster'),
    ),
  );

  // Placeholder for layer image names
  final List<Map<String, dynamic>> layersData = [];

  // Generate PNG files and add them to the archive
  for (int i = 0; i < appModel.layers.length; i++) {
    final PaintLayer layer = appModel.layers.get(i);
    final String imageName = 'data/layer-$i.png';

    // Save layer image as PNG
    final ui.Image image =
        await layer.toImage(Offset.zero, appModel.canvasSize);

    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);

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
      'opacity': layer.opacity.toString(),
      'src': imageName,
      'x': appModel.offset.dx.toString(),
      'y': appModel.offset.dy.toString(),
    });
  }

  // Create stack.xml synchronously
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element(
    'image',
    nest: () {
      builder.attribute('version', '0.0.1');
      builder.attribute('w', appModel.canvasSize.width.toInt().toString());
      builder.attribute('h', appModel.canvasSize.height.toInt().toString());

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
    ArchiveFile.noCompress(
      'stack.xml',
      stackXml.length,
      utf8.encode(stackXml),
    ),
  );

  // Write archive to file
  final List<int> encodedData = ZipEncoder().encode(archive)!;
  return encodedData;
}
