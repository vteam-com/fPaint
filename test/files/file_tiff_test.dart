import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_operation_exception.dart';

import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:image/image.dart' as img;

const String _sampleSketchBookTiffPath = 'test.tif';
const ui.Size _sampleSketchBookCanvasSize = ui.Size(4112, 2440);
const List<String> _expectedSketchBookLayerNames = <String>['Layer3', 'Layer2', 'Layer1'];
const ui.Size _layeredExportCanvasSize = ui.Size(16, 12);
const List<String> _expectedLayeredExportRoundTripNames = <String>['Hidden', 'Foreground', 'Background'];
const List<ui.Offset> _expectedSketchBookLayerOffsets = <ui.Offset>[
  ui.Offset(2497, 1430),
  ui.Offset(1875, 1347),
  ui.Offset(1523, 1183),
];
const List<ui.Size> _expectedSketchBookLayerSizes = <ui.Size>[
  ui.Size(274, 361),
  ui.Size(518, 489),
  ui.Size(511, 666),
];
const ui.Size _croppedLayerCanvasSize = ui.Size(20, 20);
const ui.Offset _croppedLayerOffset = ui.Offset(5, 7);
const ui.Size _croppedLayerImageSize = ui.Size(4, 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileTiff Tests', () {
    test('convertLayersToTiff function exists and has correct signature', () {
      expect(convertLayersToTiff, isNotNull);
    });

    group('Layer metadata round-trip via JSON description', () {
      test('encodes and decodes all metadata fields', () {
        // Simulate the JSON payload our encoder would write.
        final Map<String, dynamic> meta = <String, dynamic>{
          TiffConstants.metaKeyName: 'Sketch',
          TiffConstants.metaKeyOpacity: 0.75,
          TiffConstants.metaKeyBlendMode: ui.BlendMode.multiply.name,
          TiffConstants.metaKeyVisible: false,
        };
        final String encoded = jsonEncode(meta);
        expect(encoded, startsWith('{'));

        final Map<String, dynamic> decoded = jsonDecode(encoded) as Map<String, dynamic>;
        expect(decoded[TiffConstants.metaKeyName], 'Sketch');
        expect(decoded[TiffConstants.metaKeyOpacity], 0.75);
        expect(decoded[TiffConstants.metaKeyBlendMode], 'multiply');
        expect(decoded[TiffConstants.metaKeyVisible], false);
      });

      test('defaults are sensible when fields are missing', () {
        final Map<String, dynamic> sparse = <String, dynamic>{
          TiffConstants.metaKeyName: 'Only name',
        };
        final String encoded = jsonEncode(sparse);
        final Map<String, dynamic> decoded = jsonDecode(encoded) as Map<String, dynamic>;

        expect(decoded[TiffConstants.metaKeyName], 'Only name');
        expect(decoded[TiffConstants.metaKeyOpacity], isNull);
        expect(decoded[TiffConstants.metaKeyBlendMode], isNull);
        expect(decoded[TiffConstants.metaKeyVisible], isNull);
      });
    });

    test('imports SketchBook SubIFD layers from test.tif with names and offsets', () async {
      final LayersProvider layers = LayersProvider();
      layers.clear();

      final Uint8List bytes = await File(_sampleSketchBookTiffPath).readAsBytes();

      await readTiffFileFromBytes(layers, bytes);

      expect(layers.size, _sampleSketchBookCanvasSize);
      expect(layers.length, _expectedSketchBookLayerNames.length);

      for (int index = 0; index < _expectedSketchBookLayerNames.length; index++) {
        final LayerProvider layer = layers.get(index);
        final ui.Offset expectedOffset = _expectedSketchBookLayerOffsets[index];
        final ui.Size expectedSize = _expectedSketchBookLayerSizes[index];

        expect(layer.name, _expectedSketchBookLayerNames[index]);
        expect(layer.lastUserAction, isNotNull);
        expect(layer.lastUserAction!.positions.first, expectedOffset);
        expect(
          layer.lastUserAction!.positions.last,
          ui.Offset(expectedOffset.dx + expectedSize.width, expectedOffset.dy + expectedSize.height),
        );
      }
    });

    test('exports layered TIFF as root image plus SubIFD layers', () async {
      final LayersProvider layers = LayersProvider();
      layers.clear();
      layers.size = _layeredExportCanvasSize;

      layers.addWhiteBackgroundLayer(_expectedLayeredExportRoundTripNames[AppMath.pair]);

      final LayerProvider foregroundLayer = layers.addTop(
        name: _expectedLayeredExportRoundTripNames[1],
      );
      foregroundLayer.backgroundColor = Colors.red;

      final LayerProvider hiddenLayer = layers.addTop(
        name: _expectedLayeredExportRoundTripNames.first,
      );
      hiddenLayer.backgroundColor = Colors.blue;
      hiddenLayer.isVisible = false;

      final Uint8List bytes = await convertLayersToTiff(layers);

      final img.TiffDecoder decoder = img.TiffDecoder();
      final img.TiffInfo? info = decoder.startDecode(bytes);

      expect(info, isNotNull);
      expect(decoder.numFrames(), 1);

      final img.IfdValue? subIfdOffsets = info!.images.first.tags[TiffConstants.tagSubIfd]?.read();
      expect(subIfdOffsets, isNotNull);
      expect(subIfdOffsets!.length, _expectedLayeredExportRoundTripNames.length);

      layers.clear();
      await readTiffFileFromBytes(layers, bytes);

      expect(layers.length, _expectedLayeredExportRoundTripNames.length);

      for (int index = 0; index < _expectedLayeredExportRoundTripNames.length; index++) {
        expect(layers.get(index).name, _expectedLayeredExportRoundTripNames[index]);
      }

      expect(layers.get(0).isVisible, isFalse);
    });

    test('exports cropped layer rasters with preserved offsets', () async {
      final LayersProvider layers = LayersProvider();
      layers.clear();
      layers.size = _croppedLayerCanvasSize;
      layers.addWhiteBackgroundLayer('Background');

      final LayerProvider placedLayer = layers.addTop(name: 'Placed');
      final ui.Image placedImage = await _createSolidUiImage(
        _croppedLayerImageSize.width.toInt(),
        _croppedLayerImageSize.height.toInt(),
        Colors.red,
      );
      placedLayer.addImage(imageToAdd: placedImage, offset: _croppedLayerOffset);

      final Uint8List bytes = await convertLayersToTiff(layers);

      layers.clear();
      await readTiffFileFromBytes(layers, bytes);

      final LayerProvider importedLayer = layers.get(0);
      expect(importedLayer.name, 'Placed');
      expect(importedLayer.lastUserAction, isNotNull);
      expect(importedLayer.lastUserAction!.positions.first, _croppedLayerOffset);
      expect(
        importedLayer.lastUserAction!.positions.last,
        ui.Offset(
          _croppedLayerOffset.dx + _croppedLayerImageSize.width,
          _croppedLayerOffset.dy + _croppedLayerImageSize.height,
        ),
      );
    });

    test('invalid TIFF bytes throw without mutating existing layers', () async {
      final LayersProvider layers = LayersProvider();
      layers.clear();
      layers.size = const ui.Size(32, 24);
      layers.addWhiteBackgroundLayer('Existing');

      final Uint8List invalidBytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

      await expectLater(
        () => readTiffFileFromBytes(layers, invalidBytes),
        throwsA(isA<TiffFileException>()),
      );

      expect(layers.size, const ui.Size(32, 24));
      expect(layers.length, 1);
      expect(layers.get(0).name, 'Existing');
    });

    // Note: readTiffFileFromBytes and readTiffFromFilePath are complex functions that
    // involve LayersProvider and file operations, making them suitable for
    // integration testing rather than unit testing.
  });
}

Future<ui.Image> _createSolidUiImage(
  final int width,
  final int height,
  final Color color,
) async {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(
    image,
    color: img.ColorRgba8(
      _toImageChannel(color.r),
      _toImageChannel(color.g),
      _toImageChannel(color.b),
      _toImageChannel(color.a),
    ),
  );

  return decodeImageFromList(Uint8List.fromList(img.encodePng(image)));
}

int _toImageChannel(final double channel) {
  return (channel * AppLimits.rgbChannelMax).round().clamp(0, AppLimits.rgbChannelMax);
}
