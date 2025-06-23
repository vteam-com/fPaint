import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:xml/xml.dart';

void main() {
  test('getBlendModeFromOraCompositOp returns correct blend modes', () {
    expect(
      getBlendModeFromOraCompositOp('svg:source-over'),
      ui.BlendMode.srcOver,
    );
    expect(
      getBlendModeFromOraCompositOp('svg:multiply'),
      ui.BlendMode.multiply,
    );
    expect(getBlendModeFromOraCompositOp('svg:screen'), ui.BlendMode.screen);
    expect(getBlendModeFromOraCompositOp('svg:overlay'), ui.BlendMode.overlay);
    expect(getBlendModeFromOraCompositOp('unknown'), ui.BlendMode.srcOver);
  });

  test('readOraFile throws exception for non-existent file', () async {
    final LayersProvider layers = LayersProvider();

    expect(
      () => readImageFromFilePathOra(layers, 'nonexistent.ora'),
      throwsException,
    );
  });

  test('createOraAchive creates valid archive structure', () async {
    final LayersProvider layers = LayersProvider();
    layers.size = const ui.Size(100, 100);

    final List<int> archiveData = await createOraAchive(layers);
    final Archive archive = ZipDecoder().decodeBytes(archiveData);

    expect(
      archive.files.any((final ArchiveFile file) => file.name == 'mimetype'),
      true,
    );
    expect(
      archive.files.any((final ArchiveFile file) => file.name == 'stack.xml'),
      true,
    );

    final ArchiveFile mimetypeFile = archive.files.firstWhere((final ArchiveFile f) => f.name == 'mimetype');
    final String mimetype = String.fromCharCodes(mimetypeFile.content);
    expect(mimetype, 'image/openraster');
  });

  test('readOraFileFromBytes throws exception for invalid archive', () async {
    final LayersProvider layers = LayersProvider();
    final Uint8List invalidBytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    expect(
      () => readOraFileFromBytes(layers, invalidBytes),
      throwsException,
    );
  });

  test('buildLayers creates correct XML structure', () {
    final XmlBuilder builder = XmlBuilder();
    final List<Map<String, Object>> layersData = <Map<String, Object>>[
      <String, Object>{
        'name': 'test layer',
        'visibility': 'visible',
        'opacity': '1.00000',
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
    expect(layer.getAttribute('src'), 'data/layer-0.png');
  });

  test('buildLayers creates correct XML structure with group', () async {
    final String input = '''<?xml version="1.0" encoding="UTF-8"?>
          <image version="0.0.1" w="1920" h="1080">
            <stack>
              <stack name="Fruits">
                <layer name="Orange" visibility="visible" opacity="1.00000" src="data/layer-0.png" x="0" y="0"/>
                <layer name="Banna" visibility="visible" opacity="1.00000" src="data/layer-1.png" x="0" y="0"/>
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
    expect(layers.list[1].name, 'Banna');
    expect(layers.list[2].name, 'Pasted Layer');
    expect(layers.list[3].name, 'Background');
  });
}
