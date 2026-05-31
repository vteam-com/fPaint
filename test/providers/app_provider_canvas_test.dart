import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppProvider appProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
  });

  group('toCanvas / fromCanvas', () {
    test('identity at scale=1 and offset=zero', () {
      const Offset screen = Offset(100, 200);
      expect(appProvider.toCanvas(screen), screen);
      expect(appProvider.fromCanvas(screen), screen);
    });

    test('round-trip at default state', () {
      const Offset original = Offset(42, 99);
      final Offset canvas = appProvider.toCanvas(original);
      final Offset back = appProvider.fromCanvas(canvas);
      expect(back.dx, closeTo(original.dx, AppMath.tinyPercentage));
      expect(back.dy, closeTo(original.dy, AppMath.tinyPercentage));
    });

    test('accounts for canvasOffset', () {
      appProvider.canvasOffset = const Offset(50, 100);
      final Offset result = appProvider.toCanvas(const Offset(150, 300));
      expect(result, const Offset(100, 200));
    });

    test('accounts for scale', () {
      appProvider.layers.scale = 2.0;
      final Offset result = appProvider.toCanvas(const Offset(200, 400));
      expect(result, const Offset(100, 200));
    });

    test('fromCanvas accounts for scale', () {
      appProvider.layers.scale = 2.0;
      final Offset result = appProvider.fromCanvas(const Offset(100, 200));
      expect(result, const Offset(200, 400));
    });
  });

  group('resetView', () {
    test('resets offset and scale', () {
      appProvider.canvasOffset = const Offset(50, 100);
      appProvider.layers.scale = 3.0;
      appProvider.resetView();
      expect(appProvider.canvasOffset, Offset.zero);
      expect(appProvider.layers.scale, 1.0);
    });

    test('notifies listeners', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.resetView();
      expect(notifyCount, 1);
    });
  });

  group('canvasClear', () {
    test('resets layers to a single white background layer', () {
      appProvider.canvasClear(const Size(800, 600));
      expect(appProvider.layers.length, 1);
      expect(appProvider.layers.selectedLayerIndex, 0);
      expect(appProvider.canvasOffset, Offset.zero);
      expect(appProvider.layers.scale, 1.0);
    });

    test('sets canvas size', () {
      appProvider.canvasClear(const Size(1024, 768));
      expect(appProvider.layers.width, 1024);
      expect(appProvider.layers.height, 768);
    });
  });

  group('canvasCenter', () {
    test('returns center of canvas at default state', () {
      final double expectedX = appProvider.layers.width / AppMath.pair;
      final double expectedY = appProvider.layers.height / AppMath.pair;
      final Offset center = appProvider.canvasCenter;
      expect(center.dx, closeTo(expectedX, AppMath.tinyPercentage));
      expect(center.dy, closeTo(expectedY, AppMath.tinyPercentage));
    });

    test('accounts for offset and scale', () {
      appProvider.canvasOffset = const Offset(10, 20);
      appProvider.layers.scale = 2.0;
      final Offset center = appProvider.canvasCenter;
      expect(
        center.dx,
        closeTo(10 + (appProvider.layers.width / AppMath.pair) * 2.0, AppMath.tinyPercentage),
      );
      expect(
        center.dy,
        closeTo(20 + (appProvider.layers.height / AppMath.pair) * 2.0, AppMath.tinyPercentage),
      );
    });
  });

  group('applyScaleToCanvas', () {
    test('multiplies existing scale', () {
      appProvider.layers.scale = 1.0;
      appProvider.applyScaleToCanvas(scaleDelta: 2.0);
      expect(appProvider.layers.scale, 2.0);
    });

    test('successive scales compound', () {
      appProvider.layers.scale = 1.0;
      appProvider.applyScaleToCanvas(scaleDelta: 2.0);
      appProvider.applyScaleToCanvas(scaleDelta: 3.0);
      expect(appProvider.layers.scale, 6.0);
    });

    test('anchor point adjusts offset', () {
      appProvider.canvasOffset = Offset.zero;
      appProvider.layers.scale = 1.0;
      final Offset canvasBefore = appProvider.toCanvas(const Offset(100, 100));
      appProvider.applyScaleToCanvas(
        scaleDelta: 2.0,
        anchorPoint: const Offset(100, 100),
      );
      // After zoom the anchor point should still map to the same canvas coordinate
      final Offset canvasAfter = appProvider.toCanvas(const Offset(100, 100));
      expect(canvasAfter.dx, closeTo(canvasBefore.dx, 1));
      expect(canvasAfter.dy, closeTo(canvasBefore.dy, 1));
    });

    test('notifyListener false suppresses notification', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.applyScaleToCanvas(scaleDelta: 2.0, notifyListener: false);
      expect(notifyCount, 0);
    });

    test('notifyViewport repaints viewport without notifying provider listeners', () {
      int notifyCount = 0;
      int viewportNotifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.viewportRepaintListenable.addListener(() => viewportNotifyCount++);

      appProvider.applyScaleToCanvas(
        scaleDelta: 2.0,
        notifyListener: false,
        notifyViewport: true,
      );

      expect(notifyCount, 0);
      expect(viewportNotifyCount, 1);
    });
  });

  group('canvasPan', () {
    test('applies offset delta', () {
      appProvider.canvasOffset = const Offset(10, 20);
      appProvider.canvasPan(offsetDelta: const Offset(5, 10));
      expect(appProvider.canvasOffset, const Offset(15, 30));
    });

    test('notifyListener false suppresses notification', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.canvasPan(offsetDelta: const Offset(5, 10), notifyListener: false);
      expect(notifyCount, 0);
    });

    test('notifyViewport repaints viewport without notifying provider listeners', () {
      int notifyCount = 0;
      int viewportNotifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.viewportRepaintListenable.addListener(() => viewportNotifyCount++);

      appProvider.canvasPan(
        offsetDelta: const Offset(5, 10),
        notifyListener: false,
        notifyViewport: true,
      );

      expect(notifyCount, 0);
      expect(viewportNotifyCount, 1);
    });

    test('notifies by default', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.canvasPan(offsetDelta: const Offset(5, 10));
      expect(notifyCount, 1);
    });
  });

  group('canvasFitToContainer', () {
    test('fits small canvas into larger container', () {
      appProvider.canvasClear(const Size(100, 100));
      appProvider.canvasFitToContainer(containerWidth: 800, containerHeight: 600);
      // After fitting, the scale should be > 1 since the canvas is smaller than the container
      expect(appProvider.layers.scale, greaterThan(1));
    });

    test('fits large canvas into smaller container', () {
      appProvider.canvasClear(const Size(2000, 2000));
      appProvider.canvasFitToContainer(containerWidth: 400, containerHeight: 300);
      expect(appProvider.layers.scale, lessThan(1));
    });
  });

  group('canvasResizeLockAspectRatio', () {
    test('can get and set', () {
      appProvider.canvasResizeLockAspectRatio = true;
      expect(appProvider.canvasResizeLockAspectRatio, isTrue);

      appProvider.canvasResizeLockAspectRatio = false;
      expect(appProvider.canvasResizeLockAspectRatio, isFalse);
    });

    test('notifies listeners', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.canvasResizeLockAspectRatio = true;
      expect(notifyCount, 1);
    });
  });
}
