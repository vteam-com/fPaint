import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/files/tiff_constants.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';

const String _sampleSketchBookTiffPath = 'test.tif';
const ui.Size _sampleSketchBookCanvasSize = ui.Size(4112, 2440);
const List<String> _expectedSketchBookLayerNames = <String>['Layer3', 'Layer2', 'Layer1'];
const ui.Size _layeredExportCanvasSize = ui.Size(16, 12);
const List<String> _expectedLayeredExportRoundTripNames = <String>['Hidden', 'Foreground', 'Background'];
// SketchBook writes YPosition from the canvas bottom, so the expected top-left
// dy is canvasHeight - YPosition - layerHeight (2440 - 1430 - 361 = 649, etc.).
const List<ui.Offset> _expectedSketchBookLayerOffsets = <ui.Offset>[
  ui.Offset(2497, 649),
  ui.Offset(1875, 604),
  ui.Offset(1523, 591),
];
const List<ui.Size> _expectedSketchBookLayerSizes = <ui.Size>[
  ui.Size(274, 361),
  ui.Size(518, 489),
  ui.Size(511, 666),
];
// Raw YPosition tag values (in pixels) from test.tif's layer SubIFDs, ordered
// top layer first to match the imported layer stack.
const List<double> _sketchBookYPositions = <double>[1430, 1347, 1183];
const ui.Size _croppedLayerCanvasSize = ui.Size(20, 20);
const ui.Offset _croppedLayerOffset = ui.Offset(5, 7);
const int _flatTiffWidth = 3;
const int _flatTiffHeight = 2;
const String _plainLayerName = 'Pencil sketch';
const String _jsonLayerName = 'From JSON';
const String _blankLayerName = 'Blank';
const int _closingBraceCode = 0x7D; // '}'
const int _fillerCode = 0x78; // 'x'
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
          TiffConstants.metaKeyLocked: true,
        };
        final String encoded = jsonEncode(meta);
        expect(encoded, startsWith('{'));

        final Map<String, dynamic> decoded = jsonDecode(encoded) as Map<String, dynamic>;
        expect(decoded[TiffConstants.metaKeyName], 'Sketch');
        expect(decoded[TiffConstants.metaKeyOpacity], 0.75);
        expect(decoded[TiffConstants.metaKeyBlendMode], 'multiply');
        expect(decoded[TiffConstants.metaKeyVisible], false);
        expect(decoded[TiffConstants.metaKeyLocked], true);
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
        expect(decoded[TiffConstants.metaKeyLocked], isNull);
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

    test('imports SketchBook layer rasters with BGRA channel order', () async {
      final LayersProvider layers = LayersProvider();
      layers.clear();

      final Uint8List bytes = await File(_sampleSketchBookTiffPath).readAsBytes();
      await readTiffFileFromBytes(layers, bytes);

      // Layer1 carries a saturated blue ink stroke at canvas (1790, 615).
      // SketchBook stores layer rasters as premultiplied BGRA despite tagging
      // them RGB, so reading the samples verbatim imported this as orange.
      final LayerProvider inkLayer = layers.get(2);
      expect(inkLayer.name, 'Layer1');

      final ui.Image layerImage = inkLayer.toImageForStorage(layers.size);
      final List<int> rgba = await _readRawPixel(layerImage, 1790, 615);

      expect(rgba[0], closeTo(34, 4));
      expect(rgba[1], closeTo(134, 4));
      expect(rgba[2], closeTo(210, 4));
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
      hiddenLayer.isLocked = true;

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
      expect(layers.get(0).isLocked, isTrue);
      expect(layers.get(1).isLocked, isFalse);
    });

    test('round-trips the selected layer', () async {
      final LayersProvider layers = LayersProvider();
      layers.clear();
      layers.size = _layeredExportCanvasSize;
      layers.addWhiteBackgroundLayer('Background');
      final LayerProvider foregroundLayer = layers.addTop(name: 'Foreground')..backgroundColor = Colors.red;
      layers.addTop(name: 'Top').backgroundColor = Colors.green;
      // Stack (top-first): Top(0), Foreground(1), Background(2). Select the middle.
      layers.selectedLayerIndex = layers.getLayerIndex(foregroundLayer);

      final Uint8List bytes = await convertLayersToTiff(layers);

      final LayersProvider restored = LayersProvider();
      restored.clear();
      await readTiffFileFromBytes(restored, bytes);

      expect(restored.selectedLayer.name, 'Foreground');
      expect(restored.getLayerIndex(restored.selectedLayer), 1);
    });

    test('defaults selection to first layer for TIFFs without a selected marker', () async {
      // test.tif is a third-party SketchBook file with no "selected" metadata,
      // exercising the backward-compatible default path.
      final LayersProvider layers = LayersProvider();
      layers.clear();

      final Uint8List bytes = await File(_sampleSketchBookTiffPath).readAsBytes();
      await readTiffFileFromBytes(layers, bytes);

      expect(layers.selectedLayerIndex, 0);
    });

    test('places SketchBook layers using bottom-left YPosition origin', () async {
      final LayersProvider layers = LayersProvider();
      layers.clear();

      final Uint8List bytes = await File(_sampleSketchBookTiffPath).readAsBytes();
      await readTiffFileFromBytes(layers, bytes);

      // Verified against the file's own flattened root composite, whose ink
      // spans y 593..1255. Reading YPosition as a top-left coordinate instead
      // put every layer ~600px too low, so assert the mirrored dy exactly.
      for (int index = 0; index < layers.length; index++) {
        final LayerProvider layer = layers.get(index);
        final ui.Offset topLeft = layer.lastUserAction!.positions.first;
        final ui.Offset bottomRight = layer.lastUserAction!.positions.last;
        final double yPosition = _sketchBookYPositions[index];
        final double layerHeight = _expectedSketchBookLayerSizes[index].height;

        expect(topLeft.dy, _sampleSketchBookCanvasSize.height - yPosition - layerHeight);
        expect(bottomRight.dy, _sampleSketchBookCanvasSize.height - yPosition);
        expect(bottomRight.dx, lessThanOrEqualTo(_sampleSketchBookCanvasSize.width));
      }
    });

    test('restores blend mode and opacity from the SketchBook LayerModel tag', () async {
      final LayersProvider layers = LayersProvider();
      layers.clear();
      layers.size = _croppedLayerCanvasSize;
      layers.addWhiteBackgroundLayer('Background');

      final LayerProvider blendedLayer = layers.addTop(name: 'Blended');
      blendedLayer.backgroundColor = Colors.red;
      blendedLayer.blendMode = ui.BlendMode.multiply;
      blendedLayer.opacity = 0.5;

      final Uint8List bytes = await convertLayersToTiff(layers);

      // The LayerModel payload is what SketchBook reads, so it must carry the
      // real blend ordinal and opacity rather than a hardcoded constant.
      final img.TiffDecoder decoder = img.TiffDecoder();
      final img.TiffInfo? info = decoder.startDecode(bytes);
      expect(info, isNotNull);
      // Real SketchBook 8.7.1 stores the blend ordinal at field 7 (after the
      // constant 161), so the multiply layer must serialize exactly like this.
      expect(
        String.fromCharCodes(bytes).contains('0.500, 00000000, 1, 0, 1, 0, 161, 1, 0, 0, 00000'),
        isTrue,
      );

      layers.clear();
      await readTiffFileFromBytes(layers, bytes);

      final LayerProvider imported = layers.get(0);
      expect(imported.name, 'Blended');
      expect(imported.blendMode, ui.BlendMode.multiply);
      expect(imported.opacity, closeTo(0.5, 0.01));
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

      // Layer rasters are stored as BGRA for SketchBook, so a full round trip
      // must still hand back the original red rather than swapped blue.
      final ui.Image importedImage = importedLayer.toImageForStorage(layers.size);
      final List<int> rgba = await _readRawPixel(
        importedImage,
        _croppedLayerOffset.dx.toInt() + 1,
        _croppedLayerOffset.dy.toInt() + 1,
      );
      expect(rgba[0], closeTo(_toImageChannel(Colors.red.r), 2));
      expect(rgba[1], closeTo(_toImageChannel(Colors.red.g), 2));
      expect(rgba[2], closeTo(_toImageChannel(Colors.red.b), 2));
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

    test('readTiffFileFromBytes throws for a corrupt header', () async {
      final LayersProvider layers = LayersProvider();
      layers.clear();

      await expectLater(
        () => readTiffFileFromBytes(layers, Uint8List.fromList(<int>[0x49, 0x49, 0x2A, 0x00, 0xFF, 0xFF, 0xFF, 0xFF])),
        throwsA(isA<TiffFileException>()),
      );
    });

    test('TIFF with valid header but no frames throws', () async {
      final LayersProvider layers = LayersProvider();
      layers.clear();

      // Create a minimal valid TIFF header pointing to offset 0 (no IFDs).
      // Little-endian TIFF header: 'II' + 42 + offset 0.
      final Uint8List minimalTiff = Uint8List.fromList(<int>[
        0x49, 0x49, // Little-endian
        0x2A, 0x00, // TIFF magic
        0x00, 0x00, 0x00, 0x00, // IFD offset = 0 (no IFDs)
      ]);

      await expectLater(
        () => readTiffFileFromBytes(layers, minimalTiff),
        throwsA(isA<TiffFileException>()),
      );
    });

    group('flat (frame-based) TIFFs', () {
      Future<LayersProvider> readFlatTiff({String? description}) async {
        final img.Image frame = img.Image(width: _flatTiffWidth, height: _flatTiffHeight);
        if (description != null) {
          frame.exif.imageIfd[TiffConstants.tagImageDescription] = img.IfdValueAscii(description);
        }
        final LayersProvider layers = LayersProvider()..clear();
        await readTiffFileFromBytes(layers, img.encodeTiff(frame));
        return layers;
      }

      test('names an undescribed frame with the fallback layer name', () async {
        final LayersProvider layers = await readFlatTiff();

        expect(layers.size, const ui.Size(_flatTiffWidth * 1.0, _flatTiffHeight * 1.0));
        expect(layers.length, 1);
        expect(
          layers.get(0).name,
          '${TiffConstants.fallbackLayerNamePrefix}${TiffConstants.fallbackLayerNameSeparator}1',
        );
      });

      test('uses a plain-text description as the layer name', () async {
        final LayersProvider layers = await readFlatTiff(description: _plainLayerName);

        expect(layers.get(0).name, _plainLayerName);
      });

      test('restores JSON metadata from the description', () async {
        final LayersProvider layers = await readFlatTiff(
          description: jsonEncode(<String, Object>{
            TiffConstants.metaKeyName: _jsonLayerName,
            TiffConstants.metaKeyVisible: false,
          }),
        );

        expect(layers.get(0).name, _jsonLayerName);
        expect(layers.get(0).isVisible, isFalse);
      });
    });

    test('exports a blank layer at full canvas size and reads malformed JSON names verbatim', () async {
      final LayersProvider source = LayersProvider()
        ..clear()
        ..size = _layeredExportCanvasSize;
      source.addTop(name: _blankLayerName);
      final Uint8List bytes = await convertLayersToTiff(source);

      // Corrupt the layer's JSON description in place (same length) so it
      // still starts with '{' but no longer parses.
      final List<int> marker = utf8.encode('{"${TiffConstants.metaKeyName}":"$_blankLayerName"');
      final int start = _indexOfBytes(bytes, marker);
      expect(start, isNonNegative);
      final int end = bytes.indexOf(_closingBraceCode, start);
      for (int index = start + 1; index <= end; index++) {
        bytes[index] = _fillerCode;
      }
      final String corruptedDescription = String.fromCharCodes(bytes.sublist(start, end + 1));

      final LayersProvider layers = LayersProvider()..clear();
      await readTiffFileFromBytes(layers, bytes);

      expect(layers.size, _layeredExportCanvasSize);
      expect(layers.get(0).name, corruptedDescription);
    });

    // Note: readTiffFileFromBytes is complex functions that
    // involve LayersProvider and file operations, making them suitable for
    // integration testing rather than unit testing.
  });
}

Future<ui.Image> _createSolidUiImage(
  int width,
  int height,
  Color color,
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

int _toImageChannel(double channel) {
  return (channel * AppLimits.rgbChannelMax).round().clamp(0, AppLimits.rgbChannelMax);
}

Future<List<int>> _readRawPixel(
  ui.Image image,
  int x,
  int y,
) async {
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  final int offset = (y * image.width + x) * 4;
  return List<int>.generate(4, (int index) => byteData!.getUint8(offset + index));
}

/// Returns the first index of [pattern] in [bytes], or -1 when absent.
int _indexOfBytes(List<int> bytes, List<int> pattern) {
  for (int start = 0; start <= bytes.length - pattern.length; start++) {
    int matched = 0;
    while (matched < pattern.length && bytes[start + matched] == pattern[matched]) {
      matched++;
    }
    if (matched == pattern.length) {
      return start;
    }
  }
  return -1;
}
