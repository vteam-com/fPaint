import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:xml/xml.dart';

void main() {
  test('getBlendModeFromOraCompositOp returns correct blend modes', () {
    expect(
      getBlendModeFromOraCompositOp('svg:source-over'),
      ui.BlendMode.srcOver,
    );
    expect(
      getBlendModeFromOraCompositOp('svg:src-over'),
      ui.BlendMode.srcOver,
    );
    expect(
      getBlendModeFromOraCompositOp('svg:multiply'),
      ui.BlendMode.multiply,
    );
    expect(getBlendModeFromOraCompositOp('svg:screen'), ui.BlendMode.screen);
    expect(getBlendModeFromOraCompositOp('svg:overlay'), ui.BlendMode.overlay);
    expect(getBlendModeFromOraCompositOp('svg:plus'), ui.BlendMode.plus);
    expect(getBlendModeFromOraCompositOp('svg:hue'), ui.BlendMode.hue);
    expect(
      getBlendModeFromOraCompositOp('svg:saturation'),
      ui.BlendMode.saturation,
    );
    expect(getBlendModeFromOraCompositOp('svg:color'), ui.BlendMode.color);
    expect(
      getBlendModeFromOraCompositOp('svg:luminosity'),
      ui.BlendMode.luminosity,
    );
    expect(getBlendModeFromOraCompositOp('unknown'), ui.BlendMode.srcOver);
  });

  test('readOraFile throws exception for non-existent file', () async {
    final LayersProvider layers = LayersProvider();

    expect(
      () => readImageFromFilePathOra(layers, 'nonexistent.ora'),
      throwsA(isA<OraFileException>()),
    );
  });

  test('createOraArchive creates valid archive structure', () async {
    final LayersProvider layers = LayersProvider();
    layers.size = const ui.Size(100, 100);

    final List<int> archiveData = await createOraArchive(layers);
    final Archive archive = ZipDecoder().decodeBytes(archiveData);

    expect(
      archive.files.any((final ArchiveFile file) => file.name == 'mimetype'),
      true,
    );
    expect(
      archive.files.any((final ArchiveFile file) => file.name == 'stack.xml'),
      true,
    );
    expect(
      archive.files.any((final ArchiveFile file) => file.name == 'mergedimage.png'),
      true,
    );
    expect(
      archive.files.any((final ArchiveFile file) => file.name == 'Thumbnails/thumbnail.png'),
      true,
    );

    final ArchiveFile mimetypeFile = archive.files.firstWhere((final ArchiveFile f) => f.name == 'mimetype');
    final String mimetype = String.fromCharCodes(mimetypeFile.content);
    expect(mimetype, 'image/openraster');
    expect(mimetypeFile.compression, CompressionType.none);

    final ArchiveFile mergedImageFile = archive.files.firstWhere(
      (final ArchiveFile file) => file.name == 'mergedimage.png',
    );
    expect(mergedImageFile.compression, CompressionType.none);

    final ArchiveFile firstLayerFile = archive.files.firstWhere(
      (final ArchiveFile file) => file.name == 'data/layer-0.png',
    );
    expect(firstLayerFile.compression, CompressionType.none);
  });

  test('extractOraPreviewPngBytes returns embedded thumbnail', () async {
    final LayersProvider layers = LayersProvider();
    layers.size = const ui.Size(100, 50);

    final List<int> archiveData = await createOraArchive(layers);
    final Uint8List? previewBytes = await extractOraPreviewPngBytes(archiveData);

    expect(previewBytes, isNotNull);

    final ui.Image previewImage = await decodeImage(previewBytes!);
    expect(previewImage.height, AppLayout.thumbnailMaxHeight.toInt());
  });

  test('createOraArchive can skip preview assets', () async {
    final LayersProvider layers = LayersProvider();
    layers.size = const ui.Size(100, 50);

    final List<int> archiveData = await createOraArchive(
      layers,
      includePreviews: false,
    );
    final Archive archive = ZipDecoder().decodeBytes(archiveData);

    expect(
      archive.files.any((final ArchiveFile file) => file.name == 'mergedimage.png'),
      isFalse,
    );
    expect(
      archive.files.any((final ArchiveFile file) => file.name == 'Thumbnails/thumbnail.png'),
      isFalse,
    );
    expect(await extractOraPreviewPngBytes(archiveData), isNull);
  });

  test('readOraFileFromBytes throws exception for invalid archive', () async {
    final LayersProvider layers = LayersProvider();
    final Uint8List invalidBytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    expect(
      () => readOraFileFromBytes(layers, invalidBytes),
      throwsA(isA<OraFileException>()),
    );
  });

  test('buildLayers creates correct XML structure', () {
    final XmlBuilder builder = XmlBuilder();
    final List<Map<String, Object>> layersData = <Map<String, Object>>[
      <String, Object>{
        'name': 'test layer',
        'visibility': 'visible',
        'opacity': '1.00000',
        'composite-op': 'svg:multiply',
        'edit-locked': true,
        'src': 'data/layer-0.png',
        'x': 0,
        'y': 0,
      },
    ];

    builder.element(
      'stack',
      nest: () {
        buildLayers(builder, layersData);
      },
    );

    final XmlDocument doc = builder.buildDocument();
    final XmlElement layer = doc.findAllElements('layer').first;

    expect(layer.getAttribute('name'), 'test layer');
    expect(layer.getAttribute('visibility'), 'visible');
    expect(layer.getAttribute('opacity'), '1.00000');
    expect(layer.getAttribute('composite-op'), 'svg:multiply');
    expect(layer.getAttribute('edit-locked'), 'true');
    expect(layer.getAttribute('src'), 'data/layer-0.png');
  });

  test('createOraArchive round-trips non-default layer blend modes', () async {
    final LayersProvider exportedLayers = LayersProvider();
    exportedLayers.size = const ui.Size(100, 100);
    exportedLayers.list[0].blendMode = ui.BlendMode.plus;

    final List<int> archiveData = await createOraArchive(exportedLayers);
    final Archive archive = ZipDecoder().decodeBytes(archiveData);
    final ArchiveFile stackFile = archive.files.firstWhere(
      (final ArchiveFile file) => file.name == 'stack.xml',
    );
    final XmlDocument xmlDoc = XmlDocument.parse(
      String.fromCharCodes(stackFile.content),
    );

    expect(
      xmlDoc.findAllElements('layer').single.getAttribute('composite-op'),
      'svg:plus',
    );

    final LayersProvider importedLayers = LayersProvider();
    await readOraFileFromBytes(
      importedLayers,
      Uint8List.fromList(archiveData),
    );

    expect(importedLayers.length, 1);
    expect(importedLayers.list[0].blendMode, ui.BlendMode.plus);
  });

  test('createOraArchive round-trips layer edit lock', () async {
    final LayersProvider exportedLayers = LayersProvider();
    exportedLayers.size = const ui.Size(100, 100);
    exportedLayers.list[0].isLocked = true;

    final List<int> archiveData = await createOraArchive(exportedLayers);
    final Archive archive = ZipDecoder().decodeBytes(archiveData);
    final ArchiveFile stackFile = archive.files.firstWhere(
      (final ArchiveFile file) => file.name == 'stack.xml',
    );
    final XmlDocument xmlDoc = XmlDocument.parse(
      String.fromCharCodes(stackFile.content),
    );

    expect(
      xmlDoc.findAllElements('layer').single.getAttribute('edit-locked'),
      'true',
    );

    final LayersProvider importedLayers = LayersProvider();
    await readOraFileFromBytes(
      importedLayers,
      Uint8List.fromList(archiveData),
    );

    expect(importedLayers.length, 1);
    expect(importedLayers.list[0].isLocked, isTrue);
  });

  test('createOraArchive crops sparse layer PNGs and preserves offsets', () async {
    final LayersProvider exportedLayers = LayersProvider();
    exportedLayers.clear();
    exportedLayers.size = const ui.Size(20, 20);
    final LayerProvider placedLayer = exportedLayers.addTop(name: 'Placed');

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final ui.Paint paint = ui.Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), paint);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image placedPixel = await picture.toImage(1, 1);

    placedLayer.addImage(
      imageToAdd: placedPixel,
      offset: const ui.Offset(10, 6),
    );

    final List<int> archiveData = await createOraArchive(exportedLayers);
    final Archive archive = ZipDecoder().decodeBytes(archiveData);
    final ArchiveFile stackFile = archive.files.firstWhere(
      (final ArchiveFile file) => file.name == 'stack.xml',
    );
    final XmlDocument xmlDoc = XmlDocument.parse(
      String.fromCharCodes(stackFile.content),
    );
    final XmlElement xmlLayer = xmlDoc.findAllElements('layer').single;

    expect(xmlLayer.getAttribute('x'), '10');
    expect(xmlLayer.getAttribute('y'), '6');

    final ArchiveFile layerFile = archive.files.firstWhere(
      (final ArchiveFile file) => file.name == 'data/layer-0.png',
    );
    final ui.Image exportedLayerImage = await decodeImage(
      Uint8List.fromList(layerFile.content as List<int>),
    );
    expect(exportedLayerImage.width, 1);
    expect(exportedLayerImage.height, 1);

    final LayersProvider importedLayers = LayersProvider();
    await readOraFileFromBytes(
      importedLayers,
      Uint8List.fromList(archiveData),
    );

    expect(importedLayers.list[0].name, 'Placed');
    final ui.Image importedLayerImage = importedLayers.list[0].toImageForStorage(importedLayers.size);
    final Rect? importedBounds = await getNonTransparentBounds(importedLayerImage);
    expect(importedBounds, const Rect.fromLTRB(10, 6, 11, 7));
  });

  test('buildLayers creates correct XML structure with group', () async {
    const String input = '''<?xml version="1.0" encoding="UTF-8"?>
          <image version="0.0.1" w="1920" h="1080">
            <stack>
              <stack name="Fruits">
                <layer name="Orange" visibility="visible" opacity="1.00000" src="data/layer-0.png" x="0" y="0"/>
                <layer name="Banana" visibility="hidden" opacity="1.00000" src="data/layer-1.png" x="0" y="0"/>
              </stack>
              <layer name="Pasted Layer" visibility="visible" opacity="1.00000" src="data/layer-2.png" x="0" y="0"/>
              <layer name="Background" visibility="visible" opacity="1.00000" src="data/layer-3.png" x="0" y="0"/>
            </stack>
          </image>''';

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final ui.Paint paint = ui.Paint()..color = Colors.white;

    // Draw a 1x1 white pixel
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), paint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(1, 1);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List mockPngFileAsBytes = byteData!.buffer.asUint8List();

    final Archive archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'data/layer-0.png',
          mockPngFileAsBytes,
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'data/layer-1.png',
          mockPngFileAsBytes,
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'data/layer-2.png',
          mockPngFileAsBytes,
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'data/layer-3.png',
          mockPngFileAsBytes,
        ),
      );
    final LayersProvider layers = LayersProvider();
    layers.list.clear();

    final XmlDocument xmlDoc = XmlDocument.parse(input);
    await importFromOraXml(archive, layers, xmlDoc);

    expect(layers.length, 4);
    expect(layers.list[0].name, 'Orange');
    expect(layers.list[0].isVisible, isTrue);
    expect(layers.list[1].name, 'Banana');
    expect(layers.list[1].isVisible, isFalse);
    expect(layers.list[2].name, 'Pasted Layer');
    expect(layers.list[2].isVisible, isTrue);
    expect(layers.list[3].name, 'Background');
    expect(layers.list[3].isVisible, isTrue);
  });

  test('readOraFileFromBytes throws for archive missing stack.xml', () async {
    final LayersProvider layers = LayersProvider();

    // Create a valid ZIP with no stack.xml
    final Archive archive = Archive()
      ..addFile(ArchiveFile.bytes('mimetype', Uint8List.fromList('image/openraster'.codeUnits)));
    final Uint8List zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

    expect(
      () => readOraFileFromBytes(layers, zipBytes),
      throwsA(isA<OraFileException>()),
    );
  });

  test('readOraFileFromBytes throws for stack.xml missing image element', () async {
    final LayersProvider layers = LayersProvider();

    final Archive archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'stack.xml',
          Uint8List.fromList('<?xml version="1.0"?><root/>'.codeUnits),
        ),
      );
    final Uint8List zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

    expect(
      () => readOraFileFromBytes(layers, zipBytes),
      throwsA(isA<OraFileException>()),
    );
  });

  test('readOraFileFromBytes throws for image element missing dimensions', () async {
    final LayersProvider layers = LayersProvider();

    const String xml = '<?xml version="1.0"?><image version="0.0.1"><stack/></image>';
    final Archive archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'stack.xml',
          Uint8List.fromList(xml.codeUnits),
        ),
      );
    final Uint8List zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

    expect(
      () => readOraFileFromBytes(layers, zipBytes),
      throwsA(isA<OraFileException>()),
    );
  });

  test('importFromOraXml handles layer with missing src gracefully', () async {
    const String input = '''<?xml version="1.0" encoding="UTF-8"?>
          <image version="0.0.1" w="100" h="100">
            <stack>
              <layer name="NoSrc" visibility="visible" opacity="1.0" x="0" y="0"/>
            </stack>
          </image>''';

    final Archive archive = Archive();
    final LayersProvider layers = LayersProvider();
    layers.list.clear();

    final XmlDocument xmlDoc = XmlDocument.parse(input);
    await importFromOraXml(archive, layers, xmlDoc);

    // Layer without src should still be created but with no image data.
    expect(layers.length, 1);
    expect(layers.list[0].name, 'NoSrc');
  });

  test('importFromOraXml handles layer with missing png in archive', () async {
    const String input = '''<?xml version="1.0" encoding="UTF-8"?>
          <image version="0.0.1" w="100" h="100">
            <stack>
              <layer name="MissingPng" visibility="visible" opacity="1.0" src="data/missing.png" x="0" y="0"/>
            </stack>
          </image>''';

    final Archive archive = Archive();
    final LayersProvider layers = LayersProvider();
    layers.list.clear();

    final XmlDocument xmlDoc = XmlDocument.parse(input);
    await importFromOraXml(archive, layers, xmlDoc);

    // Layer with missing PNG should be created without image.
    expect(layers.length, 1);
  });
}
