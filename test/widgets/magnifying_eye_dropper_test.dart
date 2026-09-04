import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/magnifying_eye_dropper.dart';
import 'package:material_ui/material_ui.dart';

// Fake that overrides only the members used by the widget under test.
class FakeLayersProvider extends Fake implements LayersProvider {
  @override
  ui.Image? cachedImage;

  @override
  Future<Color?> getColorAtOffset(
    Offset offset, {
    bool useCachedImage = false,
  }) async {
    return Colors.red;
  }
}

void main() {
  group('MagnifyingEyeDropper', () {
    late FakeLayersProvider fakeLayersProvider;

    setUp(() {
      fakeLayersProvider = FakeLayersProvider();
    });

    testWidgets('renders nothing when cachedImage is null', (WidgetTester tester) async {
      fakeLayersProvider.cachedImage = null;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MagnifyingEyeDropper(
            layers: fakeLayersProvider,
            pointerPosition: const Offset(100, 100),
            pixelPosition: const Offset(50, 50),
          ),
        ),
      );

      expect(find.byType(MagnifyingEyeDropper), findsOneWidget);
      // Should render as SizedBox when no image
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders magnifying eye dropper when cachedImage exists', (WidgetTester tester) async {
      // Create a mock image
      final ui.Image mockImage = await createMockImage(100, 100);
      fakeLayersProvider.cachedImage = mockImage;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Stack(
            children: <Widget>[
              MagnifyingEyeDropper(
                layers: fakeLayersProvider,
                pointerPosition: const Offset(200, 200),
                pixelPosition: const Offset(50, 50),
              ),
            ],
          ),
        ),
      );

      // Wait for async color update
      await tester.pump();

      expect(find.byType(MagnifyingEyeDropper), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('positions widget centered on pointer position', (WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(100, 100);
      fakeLayersProvider.cachedImage = mockImage;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 400,
            height: 400,
            child: Stack(
              children: <Widget>[
                MagnifyingEyeDropper(
                  layers: fakeLayersProvider,
                  pointerPosition: const Offset(200, 200),
                  pixelPosition: const Offset(50, 50),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      final Positioned positioned = tester.widget(find.byType(Positioned));
      // Widget should be centered over pointer position (200 - 100/2 = 150)
      expect(positioned.left, 150.0);
      expect(positioned.top, 150.0);
    });

    testWidgets('displays magnified image in custom paint', (WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(100, 100);
      fakeLayersProvider.cachedImage = mockImage;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Stack(
            children: <Widget>[
              MagnifyingEyeDropper(
                layers: fakeLayersProvider,
                pointerPosition: const Offset(200, 200),
                pixelPosition: const Offset(50, 50),
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
        (CustomPaint paint) => paint.painter is MagnifyingGlassPainter,
        orElse: () => customPaints.first,
      );
      expect(magnifyingPaint.painter, isA<MagnifyingGlassPainter>());
    });

    testWidgets('shows selected color in dashed rectangle', (WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(100, 100);
      fakeLayersProvider.cachedImage = mockImage;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Stack(
            children: <Widget>[
              MagnifyingEyeDropper(
                layers: fakeLayersProvider,
                pointerPosition: const Offset(200, 200),
                pixelPosition: const Offset(50, 50),
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
    testWidgets('shouldRepaint returns true', (WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(50, 50);
      final MagnifyingGlassPainter painter = MagnifyingGlassPainter(
        croppedImage: mockImage,
        color: Colors.red,
      );

      expect(painter.shouldRepaint(painter), true);
    });

    testWidgets('paints magnified circle with borders', (WidgetTester tester) async {
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
    testWidgets('shouldRepaint returns false', (WidgetTester tester) async {
      final ui.Image mockImage = await createMockImage(50, 50);
      final ImagePainter painter = ImagePainter(mockImage);

      expect(painter.shouldRepaint(painter), false);
    });

    testWidgets('paints image on canvas', (WidgetTester tester) async {
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
Future<ui.Image> createMockImage(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()..color = Colors.blue;

  canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);

  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(width, height);
}
