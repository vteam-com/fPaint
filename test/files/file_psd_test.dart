import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/file_psd.dart';
import 'package:fpaint/files/import_file_format.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/files/psd_constants.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:image/image.dart' as img;

import '../helpers/layers_provider_test_helper.dart';
import 'psd_test_fixture.dart';

const String _samplePsdPath = 'test/test1.psd';
const ui.Size _samplePsdCanvasSize = ui.Size(4112, 2440);
// test1.psd stores a single full-canvas layer whose name carries a trailing
// space; the reader trims it.
const String _samplePsdLayerName = 'Layer1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('blendModeFromPsdBlendMode', () {
    test('maps every PSD key the compositor can express', () {
      const Map<int, ui.BlendMode> expected = <int, ui.BlendMode>{
        img.PsdBlendMode.normal: ui.BlendMode.srcOver,
        img.PsdBlendMode.passThrough: ui.BlendMode.srcOver,
        img.PsdBlendMode.darken: ui.BlendMode.darken,
        img.PsdBlendMode.multiply: ui.BlendMode.multiply,
        img.PsdBlendMode.colorBurn: ui.BlendMode.colorBurn,
        img.PsdBlendMode.lighten: ui.BlendMode.lighten,
        img.PsdBlendMode.screen: ui.BlendMode.screen,
        img.PsdBlendMode.colorDodge: ui.BlendMode.colorDodge,
        img.PsdBlendMode.overlay: ui.BlendMode.overlay,
        img.PsdBlendMode.softLight: ui.BlendMode.softLight,
        img.PsdBlendMode.hardLight: ui.BlendMode.hardLight,
        img.PsdBlendMode.difference: ui.BlendMode.difference,
        img.PsdBlendMode.exclusion: ui.BlendMode.exclusion,
        img.PsdBlendMode.hue: ui.BlendMode.hue,
        img.PsdBlendMode.saturation: ui.BlendMode.saturation,
        img.PsdBlendMode.color: ui.BlendMode.color,
        img.PsdBlendMode.luminosity: ui.BlendMode.luminosity,
      };

      expected.forEach((int psdMode, ui.BlendMode blendMode) {
        expect(
          blendModeFromPsdBlendMode(psdMode),
          blendMode,
          reason: 'PSD blend key $psdMode should map to $blendMode',
        );
      });
    });

    test('falls back to srcOver for modes Flutter cannot express', () {
      // Vivid Light, Hard Mix, Subtract, Divide and Dissolve have no Flutter
      // equivalent and must composite normally rather than throw.
      for (final int unsupported in <int>[
        img.PsdBlendMode.dissolve,
        img.PsdBlendMode.vividLight,
        img.PsdBlendMode.linearLight,
        img.PsdBlendMode.pinLight,
        img.PsdBlendMode.hardMix,
        img.PsdBlendMode.subtract,
        img.PsdBlendMode.divide,
        img.PsdBlendMode.darkenColor,
        img.PsdBlendMode.lighterColor,
        img.PsdBlendMode.linearBurn,
        img.PsdBlendMode.linearDodge,
      ]) {
        expect(blendModeFromPsdBlendMode(unsupported), ui.BlendMode.srcOver);
      }
    });

    test('falls back to srcOver for null and unknown keys', () {
      expect(blendModeFromPsdBlendMode(null), ui.BlendMode.srcOver);
      expect(blendModeFromPsdBlendMode(0), ui.BlendMode.srcOver);
      expect(blendModeFromPsdBlendMode(0xdeadbeef), ui.BlendMode.srcOver);
    });
  });

  group('readPsdFromFilePath', () {
    test('throws when the file does not exist', () async {
      final LayersProvider layers = createInitializedLayersProvider();

      expect(
        () => readPsdFromFilePath(layers, 'does/not/exist.psd'),
        throwsA(isA<PsdFileException>()),
      );
    });

    test('throws a PsdFileException for non-PSD bytes', () async {
      final LayersProvider layers = createInitializedLayersProvider();
      final Directory dir = Directory.systemTemp.createTempSync('fpaint_psd');
      addTearDown(() => dir.deleteSync(recursive: true));
      final File notAPsd = File('${dir.path}/broken.psd')..writeAsBytesSync(<int>[1, 2, 3, 4, 5, 6, 7, 8]);

      await expectLater(
        readPsdFromFilePath(layers, notAPsd.path),
        throwsA(isA<PsdFileException>()),
      );
    });

    test('loads the sample PSD into the canvas', () async {
      final LayersProvider layers = createInitializedLayersProvider();

      await readPsdFromFilePath(layers, _samplePsdPath);

      expect(layers.size, _samplePsdCanvasSize);
      expect(layers.length, 1);
      expect(layers.get(0).name, _samplePsdLayerName);
      expect(layers.get(0).isVisible, isTrue);
      expect(layers.get(0).opacity, 1.0);
      expect(layers.get(0).blendMode, ui.BlendMode.srcOver);
    });
  });

  group('readPsdFileFromBytes', () {
    test('throws a PsdFileException for invalid data', () async {
      final LayersProvider layers = createInitializedLayersProvider();

      await expectLater(
        readPsdFileFromBytes(layers, Uint8List.fromList(<int>[0, 1, 2, 3])),
        throwsA(isA<PsdFileException>()),
      );
    });

    test('rebuilds every layer bottom-to-top with its metadata', () async {
      final LayersProvider layers = createInitializedLayersProvider();
      final Uint8List psdBytes = buildTestPsd(
        width: 8,
        height: 6,
        layers: <TestPsdLayer>[
          const TestPsdLayer(
            name: 'Bottom',
            left: 0,
            top: 0,
            width: 8,
            height: 6,
            color: TestPsdColor(255, 0, 0),
          ),
          const TestPsdLayer(
            name: 'Middle',
            left: 2,
            top: 1,
            width: 4,
            height: 3,
            color: TestPsdColor(0, 255, 0),
            opacity: 128,
            blendMode: img.PsdBlendMode.multiply,
          ),
          const TestPsdLayer(
            name: 'Top',
            left: 1,
            top: 2,
            width: 2,
            height: 2,
            color: TestPsdColor(0, 0, 255),
            visible: false,
          ),
        ],
      );

      await readPsdFileFromBytes(layers, psdBytes);

      expect(layers.size, const ui.Size(8, 6));
      expect(layers.length, 3);
      // LayersProvider index 0 is the topmost layer.
      expect(
        <String>[layers.get(0).name, layers.get(1).name, layers.get(2).name],
        <String>['Top', 'Middle', 'Bottom'],
      );

      expect(layers.get(0).isVisible, isFalse);
      expect(layers.get(1).blendMode, ui.BlendMode.multiply);
      expect(layers.get(1).opacity, closeTo(128 / 255, 0.001));
      expect(layers.get(2).opacity, 1.0);
      expect(layers.get(2).blendMode, ui.BlendMode.srcOver);
    });

    test('skips group folders and keeps their child layers', () async {
      final LayersProvider layers = createInitializedLayersProvider();
      final Uint8List psdBytes = buildTestPsd(
        width: 4,
        height: 4,
        layers: <TestPsdLayer>[
          const TestPsdLayer(
            name: '</Layer group>',
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            color: TestPsdColor(0, 0, 0),
            sectionType: PsdSectionType.boundingSectionDivider,
          ),
          const TestPsdLayer(
            name: 'Inside group',
            left: 0,
            top: 0,
            width: 4,
            height: 4,
            color: TestPsdColor(10, 20, 30),
          ),
          const TestPsdLayer(
            name: 'Group',
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            color: TestPsdColor(0, 0, 0),
            sectionType: PsdSectionType.openFolder,
          ),
        ],
      );

      await readPsdFileFromBytes(layers, psdBytes);

      expect(layers.length, 1);
      expect(layers.get(0).name, 'Inside group');
    });

    test('hides the children of a hidden group', () async {
      final LayersProvider layers = createInitializedLayersProvider();
      // PSD stores layers bottom-up: the bounding divider opens the group and
      // the folder record (carrying the real visibility flag) closes it.
      final Uint8List psdBytes = buildTestPsd(
        width: 4,
        height: 4,
        layers: <TestPsdLayer>[
          const TestPsdLayer(
            name: 'Outside group',
            left: 0,
            top: 0,
            width: 4,
            height: 4,
            color: TestPsdColor(1, 1, 1),
          ),
          const TestPsdLayer(
            name: '</Layer group>',
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            color: TestPsdColor(0, 0, 0),
            sectionType: PsdSectionType.boundingSectionDivider,
          ),
          const TestPsdLayer(
            name: 'Inside hidden group',
            left: 0,
            top: 0,
            width: 4,
            height: 4,
            color: TestPsdColor(2, 2, 2),
          ),
          const TestPsdLayer(
            name: 'Hidden group',
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            color: TestPsdColor(0, 0, 0),
            visible: false,
            sectionType: PsdSectionType.closedFolder,
          ),
        ],
      );

      await readPsdFileFromBytes(layers, psdBytes);

      expect(layers.length, 2);
      // Index 0 is the topmost layer: the group's child sits above the layer
      // that was outside the group.
      expect(layers.get(0).name, 'Inside hidden group');
      expect(layers.get(0).isVisible, isFalse);
      expect(layers.get(1).name, 'Outside group');
      expect(layers.get(1).isVisible, isTrue);
    });

    test('keeps children visible when their group is visible', () async {
      final LayersProvider layers = createInitializedLayersProvider();
      final Uint8List psdBytes = buildTestPsd(
        width: 4,
        height: 4,
        layers: <TestPsdLayer>[
          const TestPsdLayer(
            name: '</Layer group>',
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            color: TestPsdColor(0, 0, 0),
            sectionType: PsdSectionType.boundingSectionDivider,
          ),
          const TestPsdLayer(
            name: 'Visible child',
            left: 0,
            top: 0,
            width: 4,
            height: 4,
            color: TestPsdColor(3, 3, 3),
          ),
          const TestPsdLayer(
            name: 'Hidden child',
            left: 0,
            top: 0,
            width: 4,
            height: 4,
            color: TestPsdColor(4, 4, 4),
            visible: false,
          ),
          const TestPsdLayer(
            name: 'Visible group',
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            color: TestPsdColor(0, 0, 0),
            sectionType: PsdSectionType.openFolder,
          ),
        ],
      );

      await readPsdFileFromBytes(layers, psdBytes);

      expect(layers.length, 2);
      // A visible group leaves each child's own visibility flag intact.
      expect(layers.get(0).name, 'Hidden child');
      expect(layers.get(0).isVisible, isFalse);
      expect(layers.get(1).name, 'Visible child');
      expect(layers.get(1).isVisible, isTrue);
    });

    test('hides a nested group child when an outer group is hidden', () async {
      final LayersProvider layers = createInitializedLayersProvider();
      final Uint8List psdBytes = buildTestPsd(
        width: 2,
        height: 2,
        layers: <TestPsdLayer>[
          const TestPsdLayer(
            name: '</Outer>',
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            color: TestPsdColor(0, 0, 0),
            sectionType: PsdSectionType.boundingSectionDivider,
          ),
          const TestPsdLayer(
            name: '</Inner>',
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            color: TestPsdColor(0, 0, 0),
            sectionType: PsdSectionType.boundingSectionDivider,
          ),
          const TestPsdLayer(
            name: 'Deep child',
            left: 0,
            top: 0,
            width: 2,
            height: 2,
            color: TestPsdColor(5, 5, 5),
          ),
          const TestPsdLayer(
            name: 'Inner group',
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            color: TestPsdColor(0, 0, 0),
            sectionType: PsdSectionType.openFolder,
          ),
          const TestPsdLayer(
            name: 'Outer group',
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            color: TestPsdColor(0, 0, 0),
            visible: false,
            sectionType: PsdSectionType.closedFolder,
          ),
        ],
      );

      await readPsdFileFromBytes(layers, psdBytes);

      expect(layers.length, 1);
      // The inner group is visible, but the hidden outer group wins.
      expect(layers.get(0).name, 'Deep child');
      expect(layers.get(0).isVisible, isFalse);
    });

    test('names a layer whose PSD record stores an empty name', () async {
      final LayersProvider layers = createInitializedLayersProvider();
      final Uint8List psdBytes = buildTestPsd(
        width: 2,
        height: 2,
        layers: <TestPsdLayer>[
          const TestPsdLayer(
            name: '   ',
            left: 0,
            top: 0,
            width: 2,
            height: 2,
            color: TestPsdColor(1, 2, 3),
          ),
        ],
      );

      await readPsdFileFromBytes(layers, psdBytes);

      expect(layers.length, 1);
      expect(layers.get(0).name, PsdConstants.unnamedLayerName);
    });

    test('falls back to the merged composite for a flattened PSD', () async {
      final LayersProvider layers = createInitializedLayersProvider();
      final Uint8List psdBytes = buildTestPsd(
        width: 5,
        height: 3,
        layers: const <TestPsdLayer>[],
      );

      await readPsdFileFromBytes(layers, psdBytes);

      expect(layers.size, const ui.Size(5, 3));
      expect(layers.length, 1);
      expect(layers.get(0).name, PsdConstants.mergedLayerName);
      expect(layers.get(0).isVisible, isTrue);
      expect(layers.get(0).opacity, 1.0);
    });

    test('replaces any existing canvas content', () async {
      final LayersProvider layers = createInitializedLayersProvider();
      layers.addTop(name: 'Pre-existing');
      expect(layers.length, greaterThan(1));

      await readPsdFileFromBytes(
        layers,
        buildTestPsd(
          width: 3,
          height: 3,
          layers: <TestPsdLayer>[
            const TestPsdLayer(
              name: 'Only',
              left: 0,
              top: 0,
              width: 3,
              height: 3,
              color: TestPsdColor(9, 9, 9),
            ),
          ],
        ),
      );

      expect(layers.length, 1);
      expect(layers.get(0).name, 'Only');
    });
  });

  group('import dispatch', () {
    test('a .psd path resolves to the PSD reader', () {
      // openFileFromPath switches on decodeKind, so this is the wiring that
      // routes a picked/dropped .psd to readPsdFromFilePath. The reader itself
      // is exercised directly above; calling openFileFromPath here would need a
      // BuildContext, and testWidgets' fake async never completes the real
      // ui.decodeImageFromList callback the reader awaits.
      final ImportFileFormat? format = ImportFileFormat.fromFileName(_samplePsdPath);

      expect(format, ImportFileFormat.psd);
      expect(format!.decodeKind, ImportDecodeKind.psd);
      expect(isFileExtensionSupported(FileExtensions.psd), isTrue);
    });
  });

  group('extractPsdPreviewPngBytes', () {
    test('returns PNG bytes for a valid PSD', () async {
      final Uint8List bytes = await File(_samplePsdPath).readAsBytes();

      final Uint8List? png = await extractPsdPreviewPngBytes(bytes);

      expect(png, isNotNull);
      final img.Image? decoded = img.decodePng(png!);
      expect(decoded, isNotNull);
      expect(decoded!.width, _samplePsdCanvasSize.width.toInt());
      expect(decoded.height, _samplePsdCanvasSize.height.toInt());
    });

    test('returns null for bytes that are not a PSD', () async {
      expect(
        await extractPsdPreviewPngBytes(Uint8List.fromList(<int>[9, 9, 9, 9])),
        isNull,
      );
    });
  });
}
