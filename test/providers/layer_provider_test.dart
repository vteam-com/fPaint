import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layer_provider.dart';

const Size _defaultSize = Size(800, 600);

/// Creates a [LayerProvider] for testing.
LayerProvider _createLayer({final String name = 'Test'}) {
  return LayerProvider(
    name: name,
    size: _defaultSize,
    onThumbnailChanged: () {},
  );
}

void main() {
  group('LayerProvider construction', () {
    test('has default name', () {
      final LayerProvider layer = _createLayer(name: 'My Layer');
      expect(layer.name, 'My Layer');
    });

    test('default visibility is true', () {
      final LayerProvider layer = _createLayer();
      expect(layer.isVisible, isTrue);
    });

    test('default opacity is 1.0', () {
      final LayerProvider layer = _createLayer();
      expect(layer.opacity, 1.0);
    });

    test('actionStack is empty initially', () {
      final LayerProvider layer = _createLayer();
      expect(layer.isEmpty, isTrue);
      expect(layer.count, 0);
    });

    test('lastUserAction is null when empty', () {
      final LayerProvider layer = _createLayer();
      expect(layer.lastUserAction, isNull);
    });

    test('blendMode defaults to srcOver', () {
      final LayerProvider layer = _createLayer();
      expect(layer.blendMode, ui.BlendMode.srcOver);
    });

    test('backgroundColor is null by default', () {
      final LayerProvider layer = _createLayer();
      expect(layer.backgroundColor, isNull);
    });

    test('hasChanged is false initially', () {
      final LayerProvider layer = _createLayer();
      expect(layer.hasChanged, isFalse);
    });

    test('preserveAlpha is true by default', () {
      final LayerProvider layer = _createLayer();
      expect(layer.preserveAlpha, isTrue);
    });

    test('size matches constructor', () {
      final LayerProvider layer = _createLayer();
      expect(layer.size, _defaultSize);
    });
  });

  group('name setter', () {
    test('updates name', () {
      final LayerProvider layer = _createLayer();
      layer.name = 'Renamed';
      expect(layer.name, 'Renamed');
    });

    test('notifies listeners', () {
      final LayerProvider layer = _createLayer();
      int notifyCount = 0;
      layer.addListener(() => notifyCount++);
      layer.name = 'New Name';
      expect(notifyCount, 1);
    });
  });

  group('isVisible setter', () {
    test('updates visibility', () {
      final LayerProvider layer = _createLayer();
      layer.isVisible = false;
      expect(layer.isVisible, isFalse);
    });
  });

  group('opacity setter', () {
    test('updates opacity', () {
      final LayerProvider layer = _createLayer();
      layer.opacity = 0.5;
      expect(layer.opacity, 0.5);
    });
  });

  group('size setter', () {
    test('updates size', () {
      final LayerProvider layer = _createLayer();
      layer.size = const Size(1024, 768);
      expect(layer.size, const Size(1024, 768));
    });
  });

  group('appendDrawingAction', () {
    test('adds action to stack', () {
      final LayerProvider layer = _createLayer();
      final UserActionDrawing action = UserActionDrawing(
        action: ActionType.brush,
        positions: <ui.Offset>[const Offset(0, 0), const Offset(10, 10)],
        brush: MyBrush(color: const Color(0xFF000000), size: 5),
      );
      layer.appendDrawingAction(action);
      expect(layer.count, 1);
      expect(layer.isEmpty, isFalse);
      expect(layer.hasChanged, isTrue);
    });

    test('lastUserAction returns the latest', () {
      final LayerProvider layer = _createLayer();
      final UserActionDrawing action1 = UserActionDrawing(
        action: ActionType.brush,
        positions: <ui.Offset>[const Offset(0, 0), const Offset(10, 10)],
        brush: MyBrush(color: const Color(0xFF000000), size: 5),
      );
      final UserActionDrawing action2 = UserActionDrawing(
        action: ActionType.pencil,
        positions: <ui.Offset>[const Offset(20, 20), const Offset(30, 30)],
        brush: MyBrush(color: const Color(0xFFFF0000), size: 3),
      );
      layer.appendDrawingAction(action1);
      layer.appendDrawingAction(action2);
      expect(layer.lastUserAction, action2);
      expect(layer.count, 2);
    });
  });

  group('undo / redo', () {
    test('undo removes last action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <ui.Offset>[const Offset(0, 0), const Offset(10, 10)],
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );
      expect(layer.count, 1);
      layer.undo();
      expect(layer.count, 0);
      expect(layer.hasChanged, isTrue);
    });

    test('redo re-applies undone action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <ui.Offset>[const Offset(0, 0), const Offset(10, 10)],
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );
      layer.undo();
      expect(layer.count, 0);
      layer.redo();
      expect(layer.count, 1);
    });

    test('undo on empty does nothing', () {
      final LayerProvider layer = _createLayer();
      layer.undo();
      expect(layer.count, 0);
    });

    test('redo on empty does nothing', () {
      final LayerProvider layer = _createLayer();
      layer.redo();
      expect(layer.count, 0);
    });

    test('multiple undo then redo round-trip', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <ui.Offset>[const Offset(0, 0)],
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <ui.Offset>[const Offset(10, 10)],
          brush: MyBrush(color: const Color(0xFFFF0000), size: 3),
        ),
      );
      expect(layer.count, 2);
      layer.undo();
      layer.undo();
      expect(layer.count, 0);
      layer.redo();
      layer.redo();
      expect(layer.count, 2);
    });
  });

  group('lastActionAppendPosition', () {
    test('adds position to last action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <ui.Offset>[const Offset(0, 0)],
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );
      layer.lastActionAppendPosition(position: const Offset(50, 50));
      expect(layer.lastUserAction!.positions.length, 2);
      expect(layer.lastUserAction!.positions.last, const Offset(50, 50));
    });
  });

  group('offset', () {
    test('translates all action positions', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <ui.Offset>[const Offset(10, 20), const Offset(30, 40)],
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );
      layer.offset(const Offset(5, 10));
      expect(layer.lastUserAction!.positions[0], const Offset(15, 30));
      expect(layer.lastUserAction!.positions[1], const Offset(35, 50));
    });
  });

  group('scale', () {
    test('scales all action positions', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <ui.Offset>[const Offset(10, 20), const Offset(30, 40)],
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );
      layer.scale(2.0);
      expect(layer.lastUserAction!.positions[0], const Offset(20, 40));
      expect(layer.lastUserAction!.positions[1], const Offset(60, 80));
    });
  });

  group('update', () {
    test('notifies listeners', () {
      final LayerProvider layer = _createLayer();
      int notifyCount = 0;
      layer.addListener(() => notifyCount++);
      layer.update();
      expect(notifyCount, 1);
    });
  });

  group('renderLayer', () {
    test('renders empty layer without error', () {
      final LayerProvider layer = _createLayer();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
      // No errors expected
    });

    test('renders layer with background color', () {
      final LayerProvider layer = _createLayer();
      layer.backgroundColor = const Color(0xFFFF0000);
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renders layer with brush action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <ui.Offset>[const Offset(10, 10), const Offset(50, 50)],
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
          fillColor: const Color(0xFF000000),
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renders layer with pencil action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <ui.Offset>[const Offset(10, 10), const Offset(50, 50)],
          brush: MyBrush(color: const Color(0xFF000000), size: 2),
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renders layer with line action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.line,
          positions: <ui.Offset>[const Offset(10, 10), const Offset(90, 90)],
          brush: MyBrush(color: const Color(0xFF000000), size: 3),
          fillColor: const Color(0xFF000000),
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renders layer with rectangle action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.rectangle,
          positions: <ui.Offset>[const Offset(10, 10), const Offset(90, 90)],
          brush: MyBrush(color: const Color(0xFF000000), size: 3),
          fillColor: const Color(0xFFFF0000),
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renders layer with circle action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.circle,
          positions: <ui.Offset>[const Offset(50, 50), const Offset(100, 100)],
          brush: MyBrush(color: const Color(0xFF000000), size: 3),
          fillColor: const Color(0xFF00FF00),
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renders layer with eraser action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.eraser,
          positions: <ui.Offset>[const Offset(10, 10), const Offset(50, 50)],
          brush: MyBrush(color: const Color(0xFF000000), size: 10),
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renders layer with cut action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.cut,
          positions: <ui.Offset>[],
          path: Path()..addRect(const Rect.fromLTWH(10, 10, 50, 50)),
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renders layer with fill action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.fill,
          positions: <ui.Offset>[const Offset(50, 50)],
          fillColor: const Color(0xFF0000FF),
          path: Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100)),
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renders with clipPath', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <ui.Offset>[const Offset(10, 10), const Offset(50, 50)],
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
          fillColor: const Color(0xFF000000),
          clipPath: Path()..addRect(const Rect.fromLTWH(0, 0, 30, 30)),
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });
  });

  group('toImageForStorage', () {
    test('returns image of correct size', () {
      final LayerProvider layer = _createLayer();
      final ui.Image image = layer.toImageForStorage(_defaultSize);
      expect(image.width, _defaultSize.width.toInt());
      expect(image.height, _defaultSize.height.toInt());
    });
  });

  group('renderImageWH', () {
    test('returns image with specified dimensions', () {
      final LayerProvider layer = _createLayer();
      final ui.Image image = layer.renderImageWH(200, 150);
      expect(image.width, 200);
      expect(image.height, 150);
    });
  });

  group('applyAction', () {
    test('applies action without clipPath', () {
      final LayerProvider layer = _createLayer();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      bool called = false;
      layer.applyAction(canvas, null, (final Canvas c) {
        called = true;
      });
      expect(called, isTrue);
      recorder.endRecording();
    });

    test('applies action with clipPath', () {
      final LayerProvider layer = _createLayer();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      bool called = false;
      layer.applyAction(
        canvas,
        Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50)),
        (final Canvas c) {
          called = true;
        },
      );
      expect(called, isTrue);
      recorder.endRecording();
    });
  });

  group('rotate90Clockwise', () {
    test('rotates positions clockwise', () async {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <Offset>[const Offset(10, 20)],
          brush: MyBrush(color: const Color(0xFF000000), size: 3),
        ),
      );

      await layer.rotate90Clockwise(_defaultSize);

      // (x,y) -> (H - y, x) = (600 - 20, 10) = (580, 10)
      expect(layer.actionStack.first.positions.first.dx, closeTo(580, 1));
      expect(layer.actionStack.first.positions.first.dy, closeTo(10, 1));
    });

    test('rotates path along with positions', () async {
      final LayerProvider layer = _createLayer();
      final Path path = Path()..addRect(const Rect.fromLTWH(10, 20, 30, 40));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.region,
          positions: <Offset>[const Offset(10, 20)],
          path: path,
          fillColor: const Color(0xFFFF0000),
        ),
      );

      await layer.rotate90Clockwise(_defaultSize);

      expect(layer.actionStack.first.path, isNotNull);
    });

    test('rotates clipPath', () async {
      final LayerProvider layer = _createLayer();
      final Path clipPath = Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <Offset>[const Offset(10, 10)],
          brush: MyBrush(color: const Color(0xFF000000), size: 3),
          clipPath: clipPath,
        ),
      );

      await layer.rotate90Clockwise(_defaultSize);

      expect(layer.actionStack.first.clipPath, isNotNull);
    });

    test('rotates image action', () async {
      final LayerProvider layer = _createLayer();
      // Create a small test image
      final ui.PictureRecorder imgRec = ui.PictureRecorder();
      Canvas(imgRec).drawRect(
        const Rect.fromLTWH(0, 0, 20, 10),
        Paint()..color = const Color(0xFFFF0000),
      );
      final ui.Image testImage = imgRec.endRecording().toImageSync(20, 10);

      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.image,
          positions: <Offset>[const Offset(0, 0), const Offset(20, 10)],
          image: testImage,
        ),
      );

      await layer.rotate90Clockwise(_defaultSize);

      expect(layer.actionStack.first.image, isNotNull);
      // Image dimensions should be swapped
      expect(layer.actionStack.first.image!.width, 10);
      expect(layer.actionStack.first.image!.height, 20);
    });

    test('rotates text object position', () async {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.text,
          positions: <Offset>[const Offset(10, 20)],
          textObject: TextObject(
            text: 'Hello',
            position: const Offset(10, 20),
            color: const Color(0xFF000000),
            size: 16,
          ),
        ),
      );

      await layer.rotate90Clockwise(_defaultSize);

      expect(layer.actionStack.first.textObject, isNotNull);
      expect(layer.actionStack.first.textObject!.text, 'Hello');
    });
  });

  group('flipHorizontal', () {
    test('flips positions horizontally', () async {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <Offset>[const Offset(10, 20)],
          brush: MyBrush(color: const Color(0xFF000000), size: 3),
        ),
      );

      await layer.flipHorizontal(_defaultSize);

      // Horizontal flip: x' = width - x = 800 - 10 = 790
      expect(layer.actionStack.first.positions.first.dx, closeTo(790, 1));
      expect(layer.actionStack.first.positions.first.dy, closeTo(20, 1));
    });

    test('flips path', () async {
      final LayerProvider layer = _createLayer();
      final Path path = Path()..addRect(const Rect.fromLTWH(10, 20, 30, 40));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.region,
          positions: <Offset>[const Offset(10, 20)],
          path: path,
          fillColor: const Color(0xFFFF0000),
        ),
      );

      await layer.flipHorizontal(_defaultSize);

      expect(layer.actionStack.first.path, isNotNull);
    });

    test('flips clipPath', () async {
      final LayerProvider layer = _createLayer();
      final Path clipPath = Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <Offset>[const Offset(10, 10)],
          brush: MyBrush(color: const Color(0xFF000000), size: 3),
          clipPath: clipPath,
        ),
      );

      await layer.flipHorizontal(_defaultSize);

      expect(layer.actionStack.first.clipPath, isNotNull);
    });

    test('flips image', () async {
      final LayerProvider layer = _createLayer();
      final ui.PictureRecorder imgRec = ui.PictureRecorder();
      Canvas(imgRec).drawRect(
        const Rect.fromLTWH(0, 0, 20, 10),
        Paint()..color = const Color(0xFFFF0000),
      );
      final ui.Image testImage = imgRec.endRecording().toImageSync(20, 10);

      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.image,
          positions: <Offset>[const Offset(0, 0), const Offset(20, 10)],
          image: testImage,
        ),
      );

      await layer.flipHorizontal(_defaultSize);

      expect(layer.actionStack.first.image, isNotNull);
    });

    test('flips text object', () async {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.text,
          positions: <Offset>[const Offset(10, 20)],
          textObject: TextObject(
            text: 'Hello',
            position: const Offset(10, 20),
            color: const Color(0xFF000000),
            size: 16,
          ),
        ),
      );

      await layer.flipHorizontal(_defaultSize);

      expect(layer.actionStack.first.textObject, isNotNull);
    });
  });

  group('flipVertical', () {
    test('flips positions vertically', () async {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <Offset>[const Offset(10, 20)],
          brush: MyBrush(color: const Color(0xFF000000), size: 3),
        ),
      );

      await layer.flipVertical(_defaultSize);

      // Vertical flip: y' = height - y = 600 - 20 = 580
      expect(layer.actionStack.first.positions.first.dx, closeTo(10, 1));
      expect(layer.actionStack.first.positions.first.dy, closeTo(580, 1));
    });

    test('flips text object vertically', () async {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.text,
          positions: <Offset>[const Offset(10, 20)],
          textObject: TextObject(
            text: 'Hello',
            position: const Offset(10, 20),
            color: const Color(0xFF000000),
            size: 16,
          ),
        ),
      );

      await layer.flipVertical(_defaultSize);

      expect(layer.actionStack.first.textObject, isNotNull);
    });
  });

  group('scale', () {
    test('scales all positions by factor', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <Offset>[const Offset(10, 20), const Offset(30, 40)],
          brush: MyBrush(color: const Color(0xFF000000), size: 3),
        ),
      );

      layer.scale(2.0);

      expect(layer.actionStack.first.positions[0], const Offset(20, 40));
      expect(layer.actionStack.first.positions[1], const Offset(60, 80));
    });
  });

  group('offset with textObject', () {
    test('offsets text object position', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.text,
          positions: <Offset>[const Offset(10, 20)],
          textObject: TextObject(
            text: 'Hello',
            position: const Offset(10, 20),
            color: const Color(0xFF000000),
            size: 16,
          ),
        ),
      );

      layer.offset(const Offset(5, 10));

      expect(
        layer.actionStack.first.textObject!.position,
        const Offset(15, 30),
      );
    });
  });
}
