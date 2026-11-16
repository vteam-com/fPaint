import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';

const String _undoName = 'Layer command';
const String _topLayerName = 'Top';
const String _missingLayerName = 'Not in stack';

void main() {
  late UndoProvider undo;
  late LayersProvider layers;

  setUp(() {
    undo = UndoProvider();
    layers = LayersProvider(undoProvider: undo);
    layers.addTop(name: _topLayerName);
    undo.clear();
  });

  group('deleteLayer', () {
    test('removes the layer as one undoable entry and undo restores it in place', () async {
      final LayerProvider top = layers.get(0);
      final int countBefore = layers.length;
      layers.selectedLayerIndex = 0;

      expect(layers.deleteLayer(top, undoName: _undoName), isTrue);
      expect(layers.length, countBefore - 1);
      expect(layers.list.contains(top), isFalse);

      await undo.undo();
      expect(layers.length, countBefore);
      expect(identical(layers.get(0), top), isTrue);
      expect(layers.selectedLayerIndex, 0);

      await undo.redo();
      expect(layers.list.contains(top), isFalse);
    });

    test('records nothing for a layer that is not in the stack', () {
      final LayerProvider stranger = layers.newLayer(_missingLayerName);

      expect(layers.deleteLayer(stranger, undoName: _undoName), isFalse);
      expect(undo.canUndo, isFalse);
    });

    test('keeps the deleted layer textures alive while the record can restore them', () async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawPaint(ui.Paint());
      final ui.Image image = await recorder.endRecording().toImage(1, 1);
      final LayerProvider top = layers.get(0)..addImage(imageToAdd: image);
      undo.clear();

      layers.deleteLayer(top, undoName: _undoName);
      expect(undo.liveRetainedImages, contains(image));
    });
  });

  group('addLayerAbove', () {
    test('inserts and selects a layer above the selection, undo removes it', () async {
      layers.selectedLayerIndex = 1;
      final LayerProvider previouslySelected = layers.selectedLayer;
      final int countBefore = layers.length;

      layers.addLayerAbove(undoName: _undoName);
      expect(layers.length, countBefore + 1);
      expect(layers.selectedLayerIndex, 1);
      expect(identical(layers.get(2), previouslySelected), isTrue);

      await undo.undo();
      expect(layers.length, countBefore);
      expect(identical(layers.selectedLayer, previouslySelected), isTrue);
    });
  });
}
