import 'dart:async';
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

/// Fake that overrides only the members the puck reads. It deliberately does
/// not answer [LayersProvider.getColorAtOffset] or
/// [LayersProvider.capturePainterToImage]: the puck must take its color from
/// the 1×1 pick and its loupe from a small region, never a full canvas.
class _FakeLayersProvider extends Fake implements LayersProvider {
  @override
  Future<ui.Image> captureCompositeRegion(Rect region) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(Offset.zero & region.size, Paint()..color = Colors.blue);
    return recorder.endRecording().toImageSync(region.width.toInt(), region.height.toInt());
  }

  /// The layer [pickPixelAt] resolves to, or null for a miss.
  LayerProvider? owningLayer;

  /// When set, each hit-test parks on a completer queued here, so a test can
  /// hold samples in flight while the crosshair keeps moving.
  List<Completer<void>>? pendingHitTests;

  /// Hit-tests currently running.
  int inFlightHitTests = 0;

  /// The most hit-tests ever running at once.
  int maxInFlightHitTests = 0;

  /// The offsets passed to [pickPixelAt], in call order.
  final List<Offset> hitTestOffsets = <Offset>[];

  @override
  Future<LayerPixelPick> pickPixelAt(Offset offset) async {
    hitTestOffsets.add(offset);
    inFlightHitTests++;
    if (inFlightHitTests > maxInFlightHitTests) {
      maxInFlightHitTests = inFlightHitTests;
    }
    try {
      final List<Completer<void>>? pending = pendingHitTests;
      if (pending != null) {
        final Completer<void> gate = Completer<void>();
        pending.add(gate);
        await gate.future;
      }
      return (owningLayer: owningLayer, color: Colors.red);
    } finally {
      inFlightHitTests--;
    }
  }
}

Future<void> _pumpPuck(
  WidgetTester tester,
  _FakeLayersProvider layers, {
  Offset pointerPosition = const Offset(200, 200),
  Offset pixelPosition = const Offset(50, 50),
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
            pixelPosition: pixelPosition,
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

    testWidgets('shows the loupe immediately and captions it once the sample lands', (WidgetTester tester) async {
      final List<Completer<void>> pending = <Completer<void>>[];
      layers
        ..owningLayer = _FakeLayer('Background')
        ..pendingHitTests = pending;

      await _pumpPuck(tester, layers);
      expect(find.byType(MagnifierLoupe), findsOneWidget);
      expect(find.byType(AppText), findsNothing);

      pending.removeAt(0).complete();
      await tester.pump();
      await tester.pump();
      expect(find.widgetWithText(AppText, 'Background'), findsOneWidget);
    });

    testWidgets('captions the loupe with the layer owning the sampled pixel', (WidgetTester tester) async {
      layers.owningLayer = _FakeLayer('Background');

      await _pumpPuck(tester, layers);

      expect(find.widgetWithText(AppText, 'Background'), findsOneWidget);
    });

    testWidgets('shows no caption when no layer owns the pixel', (WidgetTester tester) async {
      layers.owningLayer = null;

      await _pumpPuck(tester, layers);

      expect(find.byType(AppText), findsNothing);
    });

    testWidgets('serializes hit-tests while the crosshair moves and resamples the latest pixel', (
      WidgetTester tester,
    ) async {
      final List<Completer<void>> pending = <Completer<void>>[];
      layers
        ..owningLayer = _FakeLayer('Background')
        ..pendingHitTests = pending;

      await _pumpPuck(tester, layers, pixelPosition: const Offset(10, 10));
      await _pumpPuck(tester, layers, pixelPosition: const Offset(20, 20));
      await _pumpPuck(tester, layers, pixelPosition: const Offset(30, 30));

      expect(layers.hitTestOffsets, <Offset>[const Offset(10, 10)]);

      pending.removeAt(0).complete();
      await tester.pump();

      expect(layers.hitTestOffsets, <Offset>[const Offset(10, 10), const Offset(30, 30)]);

      pending.removeAt(0).complete();
      await tester.pump();
      await tester.pump();

      expect(layers.maxInFlightHitTests, 1);
      expect(find.widgetWithText(AppText, 'Background'), findsOneWidget);
    });

    testWidgets('keeps updating the loupe while the crosshair is dragged', (WidgetTester tester) async {
      final List<Completer<void>> pending = <Completer<void>>[];
      layers
        ..owningLayer = _FakeLayer('Under first pixel')
        ..pendingHitTests = pending;

      await _pumpPuck(tester, layers, pixelPosition: const Offset(10, 10));
      // The drag moves on before the first sample lands, as it always does.
      await _pumpPuck(tester, layers, pixelPosition: const Offset(20, 20));

      pending.removeAt(0).complete();
      await tester.pump();
      await tester.pump();
      // The overtaken sample is still shown rather than discarded.
      expect(find.widgetWithText(AppText, 'Under first pixel'), findsOneWidget);

      layers.owningLayer = _FakeLayer('Under latest pixel');
      pending.removeAt(0).complete();
      await tester.pump();
      await tester.pump();
      expect(find.widgetWithText(AppText, 'Under latest pixel'), findsOneWidget);
    });

    testWidgets('centers the loupe on the pointer', (WidgetTester tester) async {
      layers.owningLayer = _FakeLayer('Background');

      await _pumpPuck(tester, layers, pointerPosition: const Offset(200, 200));

      final Offset topLeft = tester.getTopLeft(find.byType(MagnifierLoupe));
      expect(topLeft.dx, lessThan(200));
      expect(topLeft.dy, lessThan(200));
    });
  });
}
