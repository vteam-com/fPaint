import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/app_text.dart';
import 'package:fpaint/widgets/layer_picker_puck.dart';
import 'package:fpaint/widgets/magnifier_loupe.dart';
import 'package:material_ui/material_ui.dart';

/// Fake layer that only has to answer for its name.
class _FakeLayer extends Fake implements LayerProvider {
  _FakeLayer(this.name);

  @override
  final String name;
}

/// Fake that overrides only the members the puck reads.
class _FakeLayersProvider extends Fake implements LayersProvider {
  @override
  ui.Image? cachedImage;

  /// The layer [findTopmostOpaqueLayerAt] resolves to, or null for a miss.
  LayerProvider? owningLayer;

  @override
  Future<Color?> getColorAtOffset(
    Offset offset, {
    bool useCachedImage = false,
  }) async {
    return Colors.red;
  }

  @override
  Future<LayerProvider?> findTopmostOpaqueLayerAt(Offset offset) async => owningLayer;
}

Future<ui.Image> _createMockImage(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.blue,
  );
  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(width, height);
}

Future<void> _pumpPuck(
  WidgetTester tester,
  _FakeLayersProvider layers, {
  Offset pointerPosition = const Offset(200, 200),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Stack(
        children: <Widget>[
          LayerPickerPuck(
            layers: layers,
            pointerPosition: pointerPosition,
            pixelPosition: const Offset(50, 50),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('LayerPickerPuck', () {
    late _FakeLayersProvider layers;

    setUp(() {
      layers = _FakeLayersProvider();
    });

    testWidgets('renders nothing when there is no composited canvas yet', (WidgetTester tester) async {
      layers.cachedImage = null;

      await _pumpPuck(tester, layers);

      expect(find.byType(MagnifierLoupe), findsNothing);
    });

    testWidgets('captions the loupe with the layer owning the sampled pixel', (WidgetTester tester) async {
      layers
        ..cachedImage = await _createMockImage(100, 100)
        ..owningLayer = _FakeLayer('Background');

      await _pumpPuck(tester, layers);

      expect(find.widgetWithText(AppText, 'Background'), findsOneWidget);
    });

    testWidgets('shows no caption when no layer owns the pixel', (WidgetTester tester) async {
      layers
        ..cachedImage = await _createMockImage(100, 100)
        ..owningLayer = null;

      await _pumpPuck(tester, layers);

      expect(find.byType(AppText), findsNothing);
    });

    testWidgets('centers the loupe on the pointer', (WidgetTester tester) async {
      layers
        ..cachedImage = await _createMockImage(100, 100)
        ..owningLayer = _FakeLayer('Background');

      await _pumpPuck(tester, layers, pointerPosition: const Offset(200, 200));

      final Offset topLeft = tester.getTopLeft(find.byType(MagnifierLoupe));
      expect(topLeft.dx, lessThan(200));
      expect(topLeft.dy, lessThan(200));
    });
  });
}
