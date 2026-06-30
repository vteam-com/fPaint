import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';

/// Renders a tiny solid GPU texture for ownership/disposal assertions.
Future<ui.Image> _texture() {
  return renderCanvasImage(
    width: 2,
    height: 2,
    draw: (final ui.Canvas canvas) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 2, 2),
        Paint()..color = const Color(0xFFFF0000),
      );
    },
  );
}

UserActionDrawing _imageAction(final ui.Image image) {
  return UserActionDrawing(
    action: ActionType.image,
    positions: const <Offset>[Offset.zero, Offset(2, 2)],
    image: image,
  );
}

void main() {
  group('disposeCommittedImagesIfUnreferenced', () {
    test('disposes an orphan but keeps an image referenced by a layer stack', () async {
      final LayersProvider layers = LayersProvider();
      final ui.Image inStack = await _texture();
      final ui.Image orphan = await _texture();
      layers.list.first.actionStack.add(_imageAction(inStack));

      layers.disposeCommittedImagesIfUnreferenced(<ui.Image>[inStack, orphan]);

      expect(inStack.debugDisposed, isFalse, reason: 'still live in the action stack');
      expect(orphan.debugDisposed, isTrue, reason: 'referenced nowhere');
    });

    test('keeps an image still referenced by the redo stack', () async {
      final LayersProvider layers = LayersProvider();
      final ui.Image inRedo = await _texture();
      layers.list.first.redoStack.add(_imageAction(inRedo));

      layers.disposeCommittedImagesIfUnreferenced(<ui.Image>[inRedo]);

      expect(inRedo.debugDisposed, isFalse);
    });

    test('keeps an image a surviving undo record can resurrect', () async {
      final UndoProvider undo = UndoProvider();
      final LayersProvider layers = LayersProvider(undoProvider: undo);
      final ui.Image retained = await _texture();
      undo.recordAction(
        RecordAction(
          name: 'smudge',
          forward: () {},
          backward: () {},
          retainedImages: <ui.Image>[retained],
        ),
      );

      layers.disposeCommittedImagesIfUnreferenced(<ui.Image>[retained]);

      expect(retained.debugDisposed, isFalse, reason: 'an undo can still restore it');
    });

    test('dedupes candidates so a single orphan is only disposed once', () async {
      final LayersProvider layers = LayersProvider();
      final ui.Image orphan = await _texture();

      // Passing the same image twice must not double-dispose.
      layers.disposeCommittedImagesIfUnreferenced(<ui.Image>[orphan, orphan]);

      expect(orphan.debugDisposed, isTrue);
    });
  });

  group('UndoProvider drop wiring frees orphaned record textures', () {
    test('trim disposes the dropped record image but keeps the surviving one', () async {
      final UndoProvider undo = UndoProvider();
      // LayersProvider owns the disposal callback on this shared undo provider.
      LayersProvider(undoProvider: undo);
      final ui.Image dropped = await _texture();
      final ui.Image kept = await _texture();

      undo.executeAction(
        name: 'smudge',
        forward: () {},
        backward: () {},
        retainedImages: <ui.Image>[dropped],
      );
      undo.executeAction(
        name: 'smudge',
        forward: () {},
        backward: () {},
        retainedImages: <ui.Image>[kept],
      );

      undo.trimUndoHistoryWhere(
        predicate: (final RecordAction r) => r.name == 'smudge',
        maxKeep: 1,
      );

      expect(dropped.debugDisposed, isTrue, reason: 'oldest smudge trimmed out of history');
      expect(kept.debugDisposed, isFalse, reason: 'still the most recent smudge');
    });

    test('clear disposes every retained record texture', () async {
      final UndoProvider undo = UndoProvider();
      LayersProvider(undoProvider: undo);
      final ui.Image image = await _texture();
      undo.executeAction(
        name: 'smudge',
        forward: () {},
        backward: () {},
        retainedImages: <ui.Image>[image],
      );

      undo.clear();

      expect(image.debugDisposed, isTrue);
    });

    test('undo and redo never dispose (records only move, not drop)', () async {
      final UndoProvider undo = UndoProvider();
      LayersProvider(undoProvider: undo);
      final ui.Image image = await _texture();
      undo.executeAction(
        name: 'smudge',
        forward: () {},
        backward: () {},
        retainedImages: <ui.Image>[image],
      );

      undo.undo();
      expect(image.debugDisposed, isFalse, reason: 'moved to redo, still restorable');
      undo.redo();
      expect(image.debugDisposed, isFalse, reason: 'back on the undo stack');
    });

    test('evicting the oldest record past the cap frees its orphaned texture', () async {
      final UndoProvider undo = UndoProvider()..maxUndoHistory = 1;
      LayersProvider(undoProvider: undo);
      final ui.Image old = await _texture();
      undo.executeAction(
        name: 'merge',
        forward: () {},
        backward: () {},
        retainedImages: <ui.Image>[old],
      );

      // A second action pushes the first past the cap of 1 -> evicted.
      undo.executeAction(name: 'draw', forward: () {}, backward: () {});

      expect(old.debugDisposed, isTrue, reason: 'evicted record was its last owner');
    });

    test('recording a new action frees the cleared redo record texture', () async {
      final UndoProvider undo = UndoProvider();
      LayersProvider(undoProvider: undo);
      final ui.Image image = await _texture();
      undo.executeAction(
        name: 'smudge',
        forward: () {},
        backward: () {},
        retainedImages: <ui.Image>[image],
      );
      undo.undo(); // image now on the redo stack

      // A new action clears redo; the redo record is unreachable -> dispose.
      undo.executeAction(name: 'draw', forward: () {}, backward: () {});

      expect(image.debugDisposed, isTrue);
    });
  });

  group('rotate disposal respects undo reachability', () {
    test('rotate frees an orphaned replaced texture but keeps an undo-referenced one', () async {
      final UndoProvider undo = UndoProvider();
      final LayersProvider layers = LayersProvider(undoProvider: undo)..size = const ui.Size(4, 2);

      final ui.Image orphanImage = await _texture();
      final ui.Image referencedImage = await _texture();
      layers.list.first.actionStack
        ..add(_imageAction(orphanImage))
        ..add(_imageAction(referencedImage));

      // Simulate a prior pixel-brush record that can still restore one texture.
      undo.recordAction(
        RecordAction(
          name: 'smudge',
          forward: () {},
          backward: () {},
          retainedImages: <ui.Image>[referencedImage],
        ),
      );

      // Mirror what the rotate orchestrator does: rotate the layer, then dispose
      // the replaced textures through the reachability check.
      final List<ui.Image> replaced = await layers.list.first.rotate90Clockwise(const ui.Size(4, 2));
      layers.disposeCommittedImagesIfUnreferenced(replaced);

      expect(orphanImage.debugDisposed, isTrue, reason: 'replaced and referenced nowhere');
      expect(
        referencedImage.debugDisposed,
        isFalse,
        reason: 'an undo record can still restore it; disposing would crash that undo',
      );
    });
  });
}
