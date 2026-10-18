import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/transform_session.dart';
import 'package:fpaint/providers/transform_session_controller.dart';
import 'package:fpaint/providers/transform_session_host.dart';
import 'package:material_ui/material_ui.dart';

const ui.Size _canvasSize = ui.Size(100, 80);
const int _oversizedSide = 400;
const int _smallSide = 10;
const ui.Rect _selectionRect = ui.Rect.fromLTWH(10, 10, 20, 20);

Future<ui.Image> _solidImage(int width, int height) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.red,
  );
  return recorder.endRecording().toImage(width, height);
}

/// Records what the controller asks of its host, so the session flow can be
/// exercised without an AppProvider.
class _FakeHost implements TransformSessionHost {
  _FakeHost() : layers = LayersProvider()..size = _canvasSize;

  @override
  final LayersProvider layers;

  @override
  final SelectorModel selectorModel = SelectorModel();

  @override
  bool isSelectedLayerLocked = false;

  ui.Image? selectionImage;
  int updates = 0;
  int allLayerStarts = 0;
  int placementCommits = 0;
  final List<String> replacedRegions = <String>[];

  @override
  void cancelEffectPreview() {}

  @override
  void activateSelectionAction() {}

  @override
  void selectAll() => selectorModel.replacePath(Path()..addRect(Offset.zero & _canvasSize));

  @override
  Future<ui.Image?> createSelectionImage() async => selectionImage;

  @override
  Future<void> startTransformAllLayers() async => allLayerStarts++;

  @override
  Future<void> confirmTransformAllLayers() async {}

  @override
  void commitPlacedImage({
    required ui.Image image,
    required Offset offset,
    required ImagePlacementCommitMode commitMode,
    required ImagePlacementLayerRestoreState? layerRestoreState,
    SelectionStateSnapshot? selectionSnapshot,
    Rect? selectionBounds,
  }) => placementCommits++;

  @override
  bool replaceRegion({
    required String name,
    required Path erasePath,
    required ui.Image replacement,
    required Offset offset,
  }) {
    replacedRegions.add(name);
    return true;
  }

  @override
  void notifyLayerModifyModeChanged({required bool wasActive}) {}

  @override
  void update() => updates++;
}

void main() {
  late _FakeHost host;
  late TransformSession session;
  late TransformSessionController controller;

  setUp(() {
    host = _FakeHost();
    session = TransformSession();
    controller = TransformSessionController(host, session);
  });

  testWidgets('a paste larger than the canvas is shrunk to fit and enters a transform', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await controller.beginPaste(await _solidImage(_oversizedSide, _oversizedSide));
    });

    expect(session.imagePlacementModel.scale, lessThan(1));
    expect(session.transformModel.isVisible, isTrue);
    expect(session.transformModel.source, TransformSessionSource.clipboardPaste);
    expect(session.kind, TransformSessionKind.preparedImage);
  });

  testWidgets('a paste that already fits keeps its pixel size', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await controller.beginPaste(await _solidImage(_smallSide, _smallSide));
    });

    expect(session.imagePlacementModel.scale, 1);
  });

  testWidgets('startTransform floats the selection and confirm replaces its region', (WidgetTester tester) async {
    host.selectorModel.replacePath(Path()..addRect(_selectionRect));
    await tester.runAsync(() async {
      host.selectionImage = await _solidImage(_selectionRect.width.toInt(), _selectionRect.height.toInt());
      await controller.startTransform();
      expect(session.kind, TransformSessionKind.selection);
      await controller.confirmTransform();
    });

    expect(host.replacedRegions, hasLength(1));
    expect(session.transformModel.isVisible, isFalse);
    expect(host.selectorModel.path1, isNull);
  });

  test('startTransform defers to the all-layers flow under the All layers scope', () async {
    host.selectorModel.allLayers = true;

    await controller.startTransform();

    expect(host.allLayerStarts, 1);
    expect(session.transformModel.isVisible, isFalse);
  });

  test('startTransform refuses a locked layer', () async {
    host.isSelectedLayerLocked = true;
    host.selectorModel.replacePath(Path()..addRect(_selectionRect));

    await controller.startTransform();

    expect(session.transformModel.isVisible, isFalse);
  });

  test('cancelling a selection transform keeps the selection', () {
    host.selectorModel.replacePath(Path()..addRect(_selectionRect));

    controller.cancelTransform();

    expect(host.selectorModel.path1, isNotNull);
    expect(host.updates, 1);
  });

  test('confirming a placement with no image just ends the session', () async {
    await controller.confirmImagePlacement();

    expect(host.placementCommits, 0);
    expect(host.updates, 1);
  });
}
