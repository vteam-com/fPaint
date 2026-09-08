import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/providers/selector_geometry_controller.dart';
import 'package:fpaint/providers/selector_geometry_host.dart';
import 'package:material_ui/material_ui.dart';

/// Records what the controller asks of its host, so the geometry can be
/// exercised without an AppProvider.
class _FakeHost implements SelectorGeometryHost {
  _FakeHost({this.canvasScale = 1.0, this.canvasRotation = 0.0});

  @override
  SelectorModel selectorModel = SelectorModel();

  @override
  final double canvasScale;

  /// Viewport rotation in radians used to convert screen deltas.
  final double canvasRotation;

  @override
  Offset canvasDeltaFromScreen(Offset screenDelta) => ViewportTransform(
    offset: Offset.zero,
    scale: canvasScale,
    rotation: canvasRotation,
  ).deltaToCanvas(screenDelta);

  @override
  double canvasWidth = 200;

  @override
  double canvasHeight = 100;

  int mainViewRepaints = 0;
  int toolOptionsRepaints = 0;
  int updates = 0;
  int effectPreviewCancels = 0;
  int wandCancels = 0;
  final List<({Offset position, bool sampleAllLayers})> wandRequests = <({Offset position, bool sampleAllLayers})>[];
  int? appliedTolerance;

  @override
  void repaintMainView() => mainViewRepaints++;

  @override
  void repaintToolOptions() => toolOptionsRepaints++;

  @override
  void update() => updates++;

  @override
  void cancelEffectPreview() => effectPreviewCancels++;

  @override
  void cancelPendingWandRequest() => wandCancels++;

  @override
  void queueWandRequest({required Offset position, required bool sampleAllLayers}) {
    wandRequests.add((position: position, sampleAllLayers: sampleAllLayers));
  }

  @override
  set tolerance(int value) => appliedTolerance = value;
}

void main() {
  group('SelectorGeometryController creation', () {
    test('wand mode queues a sample and cancels any effect preview', () {
      final _FakeHost host = _FakeHost()..selectorModel.mode = SelectorMode.wand;
      final SelectorGeometryController controller = SelectorGeometryController(host);

      controller.creationStart(const Offset(10, 20), sampleAllLayers: true);

      expect(host.effectPreviewCancels, 1);
      expect(host.selectorModel.isDrawing, isTrue);
      expect(host.wandRequests, hasLength(1));
      expect(host.wandRequests.single.position, const Offset(10, 20));
      expect(host.wandRequests.single.sampleAllLayers, isTrue);
    });

    test('rectangle mode begins a drag and repaints tool options', () {
      final _FakeHost host = _FakeHost()..selectorModel.mode = SelectorMode.rectangle;
      final SelectorGeometryController controller = SelectorGeometryController(host);

      controller.creationStart(const Offset(5, 5));

      expect(host.selectorModel.isDrawing, isTrue);
      expect(host.toolOptionsRepaints, 1);
      expect(host.updates, 1);
      expect(host.wandRequests, isEmpty);
    });

    test('additional points are ignored for wand and line modes', () {
      for (final SelectorMode mode in <SelectorMode>[SelectorMode.wand, SelectorMode.line]) {
        final _FakeHost host = _FakeHost()..selectorModel.mode = mode;
        final SelectorGeometryController controller = SelectorGeometryController(host);

        controller.creationAdditionalPoint(const Offset(1, 1));

        expect(host.mainViewRepaints, 0, reason: '$mode should not repaint');
      }
    });

    test('additional points extend a drag selection', () {
      final _FakeHost host = _FakeHost()..selectorModel.mode = SelectorMode.rectangle;
      final SelectorGeometryController controller = SelectorGeometryController(host);
      controller.creationStart(const Offset(0, 0));

      controller.creationAdditionalPoint(const Offset(30, 40));

      expect(host.mainViewRepaints, 1);
    });

    test('preview is a no-op unless a line region is being drawn', () {
      final _FakeHost host = _FakeHost()..selectorModel.mode = SelectorMode.rectangle;
      final SelectorGeometryController controller = SelectorGeometryController(host);

      controller.creationPreview(const Offset(9, 9));

      expect(host.mainViewRepaints, 0);
    });

    test('creationEnd commits a drag selection', () {
      final _FakeHost host = _FakeHost()..selectorModel.mode = SelectorMode.rectangle;
      final SelectorGeometryController controller = SelectorGeometryController(host);
      controller.creationStart(const Offset(0, 0));
      controller.creationAdditionalPoint(const Offset(10, 10));

      controller.creationEnd();

      expect(host.selectorModel.isDrawing, isFalse);
      expect(host.toolOptionsRepaints, greaterThanOrEqualTo(2));
    });

    test('creationEnd leaves an open line region in progress', () {
      final _FakeHost host = _FakeHost()..selectorModel.mode = SelectorMode.line;
      final SelectorGeometryController controller = SelectorGeometryController(host);
      controller.creationStart(const Offset(0, 0));
      final int updatesBefore = host.updates;

      controller.creationEnd();

      // A polygon closes on an explicit click, never on pointer-up.
      expect(host.updates, updatesBefore);
    });

    test('closePolygon returns false when no line region is active', () {
      final _FakeHost host = _FakeHost()..selectorModel.mode = SelectorMode.rectangle;
      final SelectorGeometryController controller = SelectorGeometryController(host);

      expect(controller.creationClosePolygon(), isFalse);
    });
  });

  group('SelectorGeometryController transforms', () {
    test('translate converts the screen delta into canvas space', () {
      final _FakeHost host = _FakeHost(canvasScale: 2.0);
      final SelectorGeometryController controller = SelectorGeometryController(host);
      controller.selectAll();
      final Rect before = host.selectorModel.path1!.getBounds();

      controller.translateByScreenDelta(const Offset(20, 40));

      final Rect after = host.selectorModel.path1!.getBounds();
      // A 2x zoom halves the screen delta on the canvas.
      expect(after.left - before.left, closeTo(10, 0.001));
      expect(after.top - before.top, closeTo(20, 0.001));
      expect(host.mainViewRepaints, 1);
    });

    test('translate rotates the screen delta when the view is rotated', () {
      // A quarter-turn view: dragging right on screen must move the selection
      // up the canvas. Dividing by the zoom alone would move it right.
      final _FakeHost host = _FakeHost(canvasRotation: pi / 2);
      final SelectorGeometryController controller = SelectorGeometryController(host);
      controller.selectAll();
      final Rect before = host.selectorModel.path1!.getBounds();

      controller.translateByScreenDelta(const Offset(30, 0));

      final Rect after = host.selectorModel.path1!.getBounds();
      expect(after.left - before.left, closeTo(0, 0.001));
      expect(after.top - before.top, closeTo(-30, 0.001));
    });

    test('resize converts the screen delta into canvas space', () {
      final _FakeHost host = _FakeHost(canvasScale: 2.0);
      final SelectorGeometryController controller = SelectorGeometryController(host);
      controller.selectAll();
      final Rect before = host.selectorModel.path1!.getBounds();

      controller.resize(NineGridHandle.bottomRight, const Offset(20, 20));

      final Rect after = host.selectorModel.path1!.getBounds();
      expect(after.width, isNot(before.width));
      expect(host.mainViewRepaints, 1);
    });

    test('scaleUniform and rotate repaint the canvas', () {
      final _FakeHost host = _FakeHost();
      final SelectorGeometryController controller = SelectorGeometryController(host);
      controller.selectAll();

      controller.scaleUniform(2.0);
      controller.rotate(0.5);

      expect(host.mainViewRepaints, 2);
    });
  });

  group('SelectorGeometryController.selectAll', () {
    test('covers the whole canvas and clears prior selection state', () {
      final _FakeHost host = _FakeHost();
      final SelectorGeometryController controller = SelectorGeometryController(host);

      controller.selectAll();

      expect(host.selectorModel.isVisible, isTrue);
      expect(host.selectorModel.isDrawing, isFalse);
      expect(host.selectorModel.path2, isNull);
      expect(host.selectorModel.points, isEmpty);
      expect(host.selectorModel.math, SelectorMath.replace);
      expect(
        host.selectorModel.path1!.getBounds(),
        const Rect.fromLTWH(0, 0, 200, 100),
      );
      expect(host.effectPreviewCancels, 1);
      expect(host.wandCancels, 1);
    });
  });

  group('SelectorGeometryController wand tolerance', () {
    test('dragging right loosens and left tightens, clamped to range', () {
      final _FakeHost host = _FakeHost();
      final SelectorGeometryController controller = SelectorGeometryController(host);

      expect(controller.wandToleranceForDrag(50, 0), 50);
      expect(controller.wandToleranceForDrag(50, 100), greaterThan(50));
      expect(controller.wandToleranceForDrag(50, -100), lessThan(50));
      expect(controller.wandToleranceForDrag(1, -100000), 1);
      expect(controller.wandToleranceForDrag(99, 100000), 100);
    });

    test('resample applies the tolerance and re-queues the same anchor', () {
      final _FakeHost host = _FakeHost()..selectorModel.mode = SelectorMode.wand;
      final SelectorGeometryController controller = SelectorGeometryController(host);

      controller.wandResampleAt(
        const Offset(7, 8),
        tolerance: 42,
        sampleAllLayers: false,
      );

      expect(host.appliedTolerance, 42);
      expect(host.selectorModel.isDrawing, isTrue);
      expect(host.wandRequests.single.position, const Offset(7, 8));
    });

    test('resample is a no-op outside wand mode', () {
      final _FakeHost host = _FakeHost()..selectorModel.mode = SelectorMode.rectangle;
      final SelectorGeometryController controller = SelectorGeometryController(host);

      controller.wandResampleAt(const Offset(7, 8), tolerance: 42, sampleAllLayers: false);

      expect(host.appliedTolerance, isNull);
      expect(host.wandRequests, isEmpty);
    });
  });
}
