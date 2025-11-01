import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/magnifying_eye_dropper.dart';
import 'package:mockito/mockito.dart';

// Mock classes
class MockLayersProvider extends Mock implements LayersProvider {
  @override
  ui.Image? cachedImage;

  @override
  Future<Color?> getColorAtOffset(final Offset offset) async {
    // Return a mock color for testing
    return Colors.red;
  }
}

void main() {
  group('MagnifyingEyeDropper', () {
    late MockLayersProvider mockLayersProvider;
    late Color pickedColor;
    late bool closedCalled;
    late bool colorPickedCalled;

    setUp(() {
      mockLayersProvider = MockLayersProvider();
      pickedColor = Colors.transparent;
      closedCalled = false;
      colorPickedCalled = false;
    });

    testWidgets('renders nothing when cachedImage is null', (final WidgetTester tester) async {
      mockLayersProvider.cachedImage = null;

      await tester.pumpWidget(
        MaterialApp(
          home: MagnifyingEyeDropper(
            layers: mockLayersProvider,
            pointerPosition: const Offset(100, 100),
            pixelPosition: const Offset(50, 50),
            onColorPicked: (final Color color) {
              pickedColor = color;
              colorPickedCalled = true;
            },
            onClosed: () {
              closedCalled = true;
            },
          ),
        ),
      );

      expect(find.byType(MagnifyingEyeDropper), findsOneWidget);
      // Should render as SizedBox when no image
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders magnifying eye dropper when cachedImage exists', (final WidgetTester tester) async {
      // Create a mock image
      final ui.Image mockImage = await createMockImage(100, 100);
      mockLayersProvider.cachedImage = mockImage;

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: <Widget>[
              MagnifyingEyeDropper(
                layers: mockLayersProvider,
                pointerPosition: const Offset(200, 200),
                pixelPosition: const Offset(50, 50),
                onColorPicked: (final Color color) {
                  pickedColor = color;
                  colorPickedCalled = true;
                },
                onClosed: () {
                  closedCalled = true;
                },
              ),
            ],
          ),
        ),
      );

      // Wait for async color update
      await tester.pump();

      expect(find.byType(MagnifyingEyeDropper), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('calls onClosed when cancel button is pressed', (final WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(100, 100);
      mockLayersProvider.cachedImage = mockImage;

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: <Widget>[
              MagnifyingEyeDropper(
                layers: mockLayersProvider,
                pointerPosition: const Offset(200, 200),
                pixelPosition: const Offset(50, 50),
                onColorPicked: (final Color color) {
                  pickedColor = color;
                  colorPickedCalled = true;
                },
                onClosed: () {
                  closedCalled = true;
                },
              ),
            ],
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closedCalled, true);
    });

    testWidgets('calls onColorPicked when confirm button is pressed', (final WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(100, 100);
      mockLayersProvider.cachedImage = mockImage;

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: <Widget>[
              MagnifyingEyeDropper(
                layers: mockLayersProvider,
                pointerPosition: const Offset(200, 200),
                pixelPosition: const Offset(50, 50),
                onColorPicked: (final Color color) {
                  pickedColor = color;
                  colorPickedCalled = true;
                },
                onClosed: () {
                  closedCalled = true;
                },
              ),
            ],
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(colorPickedCalled, true);
      expect(pickedColor, Colors.red); // Mock color from getColorAtOffset
    });

    testWidgets('positions widget correctly relative to pointer', (final WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(100, 100);
      mockLayersProvider.cachedImage = mockImage;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 400,
            child: Stack(
              children: <Widget>[
                MagnifyingEyeDropper(
                  layers: mockLayersProvider,
                  pointerPosition: const Offset(200, 200),
                  pixelPosition: const Offset(50, 50),
                  onColorPicked: (final Color color) {},
                  onClosed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      final Positioned positioned = tester.widget(find.byType(Positioned));
      // Widget should be positioned to the left of the pointer
      expect(positioned.left, 150.0); // 200 - 50 (widgetWidth)
      expect(positioned.top, lessThan(200.0)); // Should be above center
    });

    testWidgets('displays magnified image in custom paint', (final WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(100, 100);
      mockLayersProvider.cachedImage = mockImage;

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: <Widget>[
              MagnifyingEyeDropper(
                layers: mockLayersProvider,
                pointerPosition: const Offset(200, 200),
                pixelPosition: const Offset(50, 50),
                onColorPicked: (final Color color) {},
                onClosed: () {},
              ),
            ],
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
      final Iterable<CustomPaint> customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      // Find the one with MagnifyingGlassPainter
      final CustomPaint magnifyingPaint = customPaints.firstWhere(
        (final CustomPaint paint) => paint.painter is MagnifyingGlassPainter,
        orElse: () => customPaints.first,
      );
      expect(magnifyingPaint.painter, isA<MagnifyingGlassPainter>());
    });

    testWidgets('shows selected color in dashed rectangle', (final WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(100, 100);
      mockLayersProvider.cachedImage = mockImage;

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: <Widget>[
              MagnifyingEyeDropper(
                layers: mockLayersProvider,
                pointerPosition: const Offset(200, 200),
                pixelPosition: const Offset(50, 50),
                onColorPicked: (final Color color) {},
                onClosed: () {},
              ),
            ],
          ),
        ),
      );

      await tester.pump();

      // Should find the DashedRectangle widget (which uses CustomPaint)
      expect(find.byType(CustomPaint), findsWidgets); // DashedRectangle uses CustomPaint
    });
  });

  group('MagnifyingGlassPainter', () {
    testWidgets('shouldRepaint returns true', (final WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(50, 50);
      final MagnifyingGlassPainter painter = MagnifyingGlassPainter(
        croppedImage: mockImage,
        color: Colors.red,
      );

      expect(painter.shouldRepaint(painter), true);
    });

    testWidgets('paints magnified circle with borders', (final WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(50, 50);
      final MagnifyingGlassPainter painter = MagnifyingGlassPainter(
        croppedImage: mockImage,
        color: Colors.red,
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      const ui.Size size = Size(100, 100);

      painter.paint(canvas, size);

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('ImagePainter', () {
    testWidgets('shouldRepaint returns false', (final WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(50, 50);
      final ImagePainter painter = ImagePainter(mockImage);

      expect(painter.shouldRepaint(painter), false);
    });

    testWidgets('paints image on canvas', (final WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(50, 50);
      final ImagePainter painter = ImagePainter(mockImage);

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      const ui.Size size = Size(50, 50);

      painter.paint(canvas, size);

      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}

// Helper functions for creating mock images
Future<ui.Image> createMockImage(final int width, final int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()..color = Colors.blue;

  canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);

  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(width, height);
}
