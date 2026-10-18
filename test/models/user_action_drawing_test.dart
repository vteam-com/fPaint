import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('UserActionDrawing', () {
    test('StrokeAction exposes its brush and fill, and no other payload', () {
      final List<Offset> positions = <Offset>[const Offset(10, 20), const Offset(30, 40)];
      final MyBrush brush = MyBrush(size: 5.0, style: BrushStyle.solid);

      final UserActionDrawing action = StrokeAction(
        action: ActionType.brush,
        positions: positions,
        brush: brush,
        fillColor: Colors.red,
      );

      expect(action.action, ActionType.brush);
      expect(action.positions, positions);
      expect(action.brush, brush);
      expect(action.fillColor, Colors.red);
      expect(action.textObject, isNull);
      expect(action.path, isNull);
      expect(action.image, isNull);
      expect(action.erasesEntireLayer, isFalse);
    });

    test('RegionAction fixes its action type and exposes fill geometry', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      final UserActionDrawing action = RegionAction(
        positions: <Offset>[Offset.zero],
        path: path,
        fillColor: Colors.blue,
      );

      expect(action.action, ActionType.region);
      expect(action.path, path);
      expect(action.fillColor, Colors.blue);
      expect(action.brush, isNull);
    });

    test('CutAction carries its erase geometry and whole-layer flag', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      final UserActionDrawing action = CutAction(path: path, erasesEntireLayer: true);

      expect(action.action, ActionType.cut);
      expect(action.path, path);
      expect(action.erasesEntireLayer, isTrue);
      expect(action.positions, isEmpty);
    });

    test('TextAction fixes its action type and exposes its text object', () {
      final TextObject textObject = TextObject(
        text: 'Test',
        position: const Offset(0, 0),
        color: Colors.black,
        size: 16.0,
      );
      final UserActionDrawing action = TextAction(
        positions: <Offset>[Offset.zero],
        textObject: textObject,
      );

      expect(action.action, ActionType.text);
      expect(action.textObject, textObject);
      expect(action.brush, isNull);
      expect(action.path, isNull);
    });

    test('NonRenderingAction keeps its action type and carries no payload', () {
      final UserActionDrawing action = NonRenderingAction(action: ActionType.fill);

      expect(action.action, ActionType.fill);
      expect(action.brush, isNull);
      expect(action.path, isNull);
      expect(action.image, isNull);
      expect(action.textObject, isNull);
    });

    test('copyWith preserves the concrete variant and replaces geometry', () {
      final MyBrush brush = MyBrush(size: 5.0, style: BrushStyle.solid);
      final StrokeAction stroke = StrokeAction(
        action: ActionType.pencil,
        positions: <Offset>[Offset.zero],
        brush: brush,
      );
      final List<Offset> moved = <Offset>[const Offset(5, 5)];
      final UserActionDrawing copied = stroke.copyWith(positions: moved);

      expect(copied, isA<StrokeAction>());
      expect(copied.action, ActionType.pencil);
      expect(copied.positions, moved);
      expect(copied.brush, brush);

      final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      final Path shifted = Path()..addRect(const Rect.fromLTWH(5, 5, 10, 10));
      final UserActionDrawing region = RegionAction(
        positions: <Offset>[Offset.zero],
        path: path,
        fillColor: Colors.blue,
      ).copyWith(path: shifted);

      expect(region, isA<RegionAction>());
      expect(region.path, shifted);
      expect(region.fillColor, Colors.blue);
    });

    test('toString returns action name', () {
      final UserActionDrawing action = StrokeAction(
        action: ActionType.pencil,
        positions: <Offset>[const Offset(0, 0)],
        brush: MyBrush(color: Colors.black, size: 2),
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

    test('isPixelBrush is true only for smudge and blur records', () {
      expect(
        ActionType.values.where((ActionType type) => type.isPixelBrush),
        <ActionType>[ActionType.smudge, ActionType.blurBrush],
      );
    });
  });

  group('AppSvgIcon', () {
    testWidgets('AppSvgIcon uses isSelected', (WidgetTester tester) async {
      const AppSvgIcon selected = AppSvgIcon(icon: AppIcon.create, isSelected: true);
      expect(selected.isSelected, true);

      const AppSvgIcon unselected = AppSvgIcon(icon: AppIcon.create, isSelected: false);
      expect(unselected.isSelected, false);
    });
  });
}
