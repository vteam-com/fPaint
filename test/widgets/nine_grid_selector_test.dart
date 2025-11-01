import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/widgets/nine_grid_selector.dart';

void main() {
  group('NineGridSelector', () {
    testWidgets('renders 3x3 grid with 9 items', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NineGridSelector(
            selectedPosition: CanvasResizePosition.center,
            onPositionSelected: (final CanvasResizePosition position) {},
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(GestureDetector), findsNWidgets(9));
    });

    testWidgets('displays correct icons for each position', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NineGridSelector(
            selectedPosition: CanvasResizePosition.center,
            onPositionSelected: (final CanvasResizePosition position) {},
          ),
        ),
      );

      // Check that we have the expected number of icons
      expect(find.byType(Icon), findsNWidgets(9));
    });

    testWidgets('highlights selected position with blue color', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NineGridSelector(
            selectedPosition: CanvasResizePosition.topLeft,
            onPositionSelected: (final CanvasResizePosition position) {},
          ),
        ),
      );

      // The selected position should have a blue background
      final Iterable<DecoratedBox> decoratedBoxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));

      // Check that at least one has blue color (the selected one)
      bool hasBlueSelected = false;
      for (final DecoratedBox decoratedBox in decoratedBoxes) {
        final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
        if (decoration.color == Colors.blue) {
          hasBlueSelected = true;
          break;
        }
      }
      expect(hasBlueSelected, true);
    });

    testWidgets('calls onPositionSelected when position is tapped', (final WidgetTester tester) async {
      CanvasResizePosition? selectedPosition;

      await tester.pumpWidget(
        MaterialApp(
          home: NineGridSelector(
            selectedPosition: CanvasResizePosition.center,
            onPositionSelected: (final CanvasResizePosition position) {
              selectedPosition = position;
            },
          ),
        ),
      );

      // Tap the first position (topLeft)
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(selectedPosition, CanvasResizePosition.topLeft);
    });

    testWidgets('has correct container dimensions and styling', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NineGridSelector(
            selectedPosition: CanvasResizePosition.center,
            onPositionSelected: (final CanvasResizePosition position) {},
          ),
        ),
      );

      final Container container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth, 120.0);
      expect(container.constraints?.maxHeight, 120.0);

      final BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('getDirectionIcon returns correct icons for each position', (final WidgetTester tester) async {
      final NineGridSelector selector = NineGridSelector(
        selectedPosition: CanvasResizePosition.center,
        onPositionSelected: (final CanvasResizePosition position) {},
      );

      // Test each position - note: the widget uses CupertinoIcons for arrows
      expect(selector.getDirectionIcon(0), CupertinoIcons.arrow_up_left); // topLeft
      expect(selector.getDirectionIcon(1), CupertinoIcons.arrow_up); // top
      expect(selector.getDirectionIcon(2), CupertinoIcons.arrow_up_right); // topRight
      expect(selector.getDirectionIcon(3), CupertinoIcons.arrow_left); // left
      expect(selector.getDirectionIcon(4), Icons.crop_square_outlined); // center
      expect(selector.getDirectionIcon(5), CupertinoIcons.arrow_right); // right
      expect(selector.getDirectionIcon(6), CupertinoIcons.arrow_down_left); // bottomLeft
      expect(selector.getDirectionIcon(7), CupertinoIcons.arrow_down); // bottom
      expect(selector.getDirectionIcon(8), CupertinoIcons.arrow_down_right); // bottomRight
    });

    testWidgets('selected position shows image icon instead of direction icon', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NineGridSelector(
            selectedPosition: CanvasResizePosition.center,
            onPositionSelected: (final CanvasResizePosition position) {},
          ),
        ),
      );

      // The center position should show an image icon when selected
      final Iterable<Icon> icons = tester.widgetList<Icon>(find.byType(Icon));
      expect(icons.length, 9);

      // At least one icon should be Icons.image (the selected one)
      bool hasImageIcon = false;
      for (final Icon icon in icons) {
        if (icon.icon == Icons.image) {
          hasImageIcon = true;
          break;
        }
      }
      expect(hasImageIcon, true);
    });
  });
}
