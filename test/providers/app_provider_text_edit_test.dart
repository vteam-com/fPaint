import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Offset _origin = Offset(10, 20);
const Offset _moved = Offset(40, 50);
const Color _black = Color(0xFF000000);
const Color _red = Color(0xFFFF0000);
const double _size = 16;
const double _biggerSize = 32;

TextObject _text(String text) => TextObject(text: text, position: _origin, color: _black, size: _size);

void main() {
  late AppProvider appProvider;
  late LayerProvider layer;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    layer = appProvider.layers.selectedLayer;
  });

  void addText(TextObject textObject) {
    appProvider.recordExecuteDrawingActionToSelectedLayer(
      action: TextAction(positions: <Offset>[textObject.position], textObject: textObject),
    );
  }

  group('updateTextObject', () {
    test('edits in place and undo/redo restore each state', () async {
      final TextObject hello = _text('Hello');
      addText(hello);

      final bool recorded = appProvider.updateTextObject(
        hello,
        hello.copyWith(text: 'World', position: _moved, color: _red, size: _biggerSize),
      );

      expect(recorded, isTrue);
      expect(hello.text, 'World');
      expect(hello.position, _moved);
      expect(hello.color, _red);
      expect(hello.size, _biggerSize);
      expect(identical(layer.actionStack.single.textObject, hello), isTrue);

      await appProvider.undoAction();
      expect(hello.text, 'Hello');
      expect(hello.position, _origin);
      expect(hello.size, _size);
      expect(layer.actionStack, hasLength(1));

      await appProvider.redoAction();
      expect(hello.text, 'World');
    });

    test('is refused for text not on the selected layer', () {
      expect(appProvider.updateTextObject(_text('Orphan'), _text('X')), isFalse);
      expect(appProvider.undoProvider.canUndo, isFalse);
    });

    test('is refused on a locked layer', () {
      final TextObject hello = _text('Hello');
      addText(hello);
      layer.isLocked = true;

      expect(appProvider.updateTextObject(hello, _text('X')), isFalse);
      expect(hello.text, 'Hello');
    });
  });

  group('deleteTextObject', () {
    test('removes from the middle of the stack and undo reinserts at the same index', () async {
      final TextObject first = _text('First');
      final TextObject middle = _text('Middle');
      final TextObject last = _text('Last');
      addText(first);
      addText(middle);
      addText(last);

      expect(appProvider.deleteTextObject(middle), isTrue);
      expect(
        layer.actionStack.map((UserActionDrawing a) => a.textObject),
        <TextObject>[first, last],
      );

      await appProvider.undoAction();
      expect(
        layer.actionStack.map((UserActionDrawing a) => a.textObject),
        <TextObject>[first, middle, last],
      );

      await appProvider.redoAction();
      expect(
        layer.actionStack.map((UserActionDrawing a) => a.textObject),
        <TextObject>[first, last],
      );
    });

    test('undoing past a delete removes the right text', () async {
      final TextObject first = _text('First');
      final TextObject last = _text('Last');
      addText(first);
      addText(last);
      appProvider.deleteTextObject(first);

      // Undo the delete, then undo "add Last": only First must remain.
      await appProvider.undoAction();
      await appProvider.undoAction();
      expect(layer.actionStack.single.textObject, same(first));
    });

    test('is refused for text not on the selected layer', () {
      expect(appProvider.deleteTextObject(_text('Orphan')), isFalse);
    });
  });
}
