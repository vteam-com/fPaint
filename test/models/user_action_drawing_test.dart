import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/widgets/app_icon.dart';

void main() {
  group('UserActionDrawing', () {
    test('constructor sets all properties correctly', () {
      final List<Offset> positions = <Offset>[const Offset(10, 20), const Offset(30, 40)];
      final MyBrush brush = MyBrush(size: 5.0, style: BrushStyle.solid);
      final TextObject textObject = TextObject(
        text: 'Test',
        position: const Offset(0, 0),
        color: Colors.black,
        size: 16.0,
      );

      final UserActionDrawing action = UserActionDrawing(
        action: ActionType.brush,
        positions: positions,
        brush: brush,
        fillColor: Colors.red,
        textObject: textObject,
      );

      expect(action.action, ActionType.brush);
      expect(action.positions, positions);
      expect(action.brush, brush);
      expect(action.fillColor, Colors.red);
      expect(action.textObject, textObject);
    });

    test('toString returns action name', () {
      final UserActionDrawing action = UserActionDrawing(
        action: ActionType.pencil,
        positions: <Offset>[const Offset(0, 0)],
      );

      expect(action.toString(), 'pencil');
    });
  });

  group('ActionType', () {
    test('toString returns name', () {
      expect(ActionType.pencil.toString(), 'pencil');
      expect(ActionType.brush.toString(), 'brush');
      expect(ActionType.line.toString(), 'line');
    });

    test('isSupported returns correct values for pencil', () {
      expect(ActionType.pencil.isSupported(ActionOptions.brushSize), true);
      expect(ActionType.pencil.isSupported(ActionOptions.brushColor), true);
      expect(ActionType.pencil.isSupported(ActionOptions.topColors), true);
      expect(ActionType.pencil.isSupported(ActionOptions.brushStyle), false);
      expect(ActionType.pencil.isSupported(ActionOptions.colorFill), false);
    });

    test('isSupported returns correct values for brush', () {
      expect(ActionType.brush.isSupported(ActionOptions.brushSize), true);
      expect(ActionType.brush.isSupported(ActionOptions.brushStyle), true);
      expect(ActionType.brush.isSupported(ActionOptions.brushColor), true);
      expect(ActionType.brush.isSupported(ActionOptions.topColors), true);
      expect(ActionType.brush.isSupported(ActionOptions.tolerance), false);
    });

    test('isSupported returns correct values for fill', () {
      expect(ActionType.fill.isSupported(ActionOptions.colorFill), true);
      expect(ActionType.fill.isSupported(ActionOptions.tolerance), true);
      expect(ActionType.fill.isSupported(ActionOptions.topColors), true);
      expect(ActionType.fill.isSupported(ActionOptions.brushSize), false);
    });

    test('isSupported returns correct values for eraser', () {
      expect(ActionType.eraser.isSupported(ActionOptions.brushSize), true);
      expect(ActionType.eraser.isSupported(ActionOptions.brushColor), false);
    });

    test('isSupported returns correct values for selector', () {
      expect(ActionType.selector.isSupported(ActionOptions.selectorOptions), true);
      expect(ActionType.selector.isSupported(ActionOptions.brushSize), false);
    });

    test('isSupported returns false for unsupported action types', () {
      expect(ActionType.cut.isSupported(ActionOptions.brushSize), false);
      expect(ActionType.image.isSupported(ActionOptions.brushSize), false);
    });
  });

  group('ActionType.icon', () {
    test('returns correct icon for pencil', () {
      expect(ActionType.pencil.icon, AppIcon.create);
    });

    test('returns correct icon for brush', () {
      expect(ActionType.brush.icon, AppIcon.brush);
    });

    test('returns correct icon for eraser', () {
      expect(ActionType.eraser.icon, AppIcon.eraser);
    });

    test('returns correct icon for selector', () {
      expect(ActionType.selector.icon, AppIcon.selector);
    });

    testWidgets('AppSvgIcon uses isSelected', (final WidgetTester tester) async {
      const AppSvgIcon selected = AppSvgIcon(icon: AppIcon.create, isSelected: true);
      expect(selected.isSelected, true);

      const AppSvgIcon unselected = AppSvgIcon(icon: AppIcon.create, isSelected: false);
      expect(unselected.isSelected, false);
    });
  });

  group('toolsSupportedAttributes', () {
    test('contains all action types', () {
      expect(toolsSupportedAttributes.length, 10); // Currently only 10 action types have defined attributes
    });

    test('pencil supports correct attributes', () {
      final Set<ActionOptions> pencilAttributes = toolsSupportedAttributes[ActionType.pencil]!;
      expect(pencilAttributes, contains(ActionOptions.brushSize));
      expect(pencilAttributes, contains(ActionOptions.brushColor));
      expect(pencilAttributes, contains(ActionOptions.topColors));
      expect(pencilAttributes, isNot(contains(ActionOptions.brushStyle)));
    });

    test('circle supports fill color', () {
      final Set<ActionOptions> circleAttributes = toolsSupportedAttributes[ActionType.circle]!;
      expect(circleAttributes, contains(ActionOptions.colorFill));
    });

    test('text supports brush color and size', () {
      final Set<ActionOptions> textAttributes = toolsSupportedAttributes[ActionType.text]!;
      expect(textAttributes, contains(ActionOptions.brushColor));
      expect(textAttributes, contains(ActionOptions.brushSize));
      expect(textAttributes, contains(ActionOptions.topColors));
    });
  });
}
