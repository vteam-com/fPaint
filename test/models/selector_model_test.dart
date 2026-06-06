import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/selector_model.dart';

class _ThrowingCombineSelectorModel extends SelectorModel {
  @override
  Path combinePaths(
    final PathOperation operation,
    final Path firstPath,
    final Path secondPath,
  ) {
    throw StateError('Path.combine() failed');
  }
}

void main() {
  late SelectorModel model;

  setUp(() {
    model = SelectorModel();
  });

  group('SelectorModel initial state', () {
    test('mode defaults to rectangle', () {
      expect(model.mode, SelectorMode.rectangle);
    });

    test('math defaults to replace', () {
      expect(model.math, SelectorMath.replace);
    });

    test('isDrawing defaults to false', () {
      expect(model.isDrawing, isFalse);
    });

    test('isVisible defaults to false', () {
      expect(model.isVisible, isFalse);
    });

    test('points is empty', () {
      expect(model.points, isEmpty);
    });

    test('path1 is null', () {
      expect(model.path1, isNull);
    });

    test('path2 is null', () {
      expect(model.path2, isNull);
    });

    test('boundingRect is Rect.zero when no path', () {
      expect(model.boundingRect, Rect.zero);
    });
  });

  group('clear', () {
    test('resets all state', () {
      model.isVisible = true;
      model.isDrawing = true;
      model.math = SelectorMath.add;
      model.path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      model.path2 = Path()..addRect(const Rect.fromLTWH(10, 10, 30, 30));
      model.points.addAll(<Offset>[Offset.zero, const Offset(10, 10)]);

      model.clear();

      expect(model.isVisible, isFalse);
      expect(model.isDrawing, isFalse);
      expect(model.path1, isNull);
      expect(model.path2, isNull);
      expect(model.points, isEmpty);
      expect(model.math, SelectorMath.replace);
    });
  });

  group('addP1 - rectangle mode', () {
    test('sets isVisible to true', () {
      model.mode = SelectorMode.rectangle;
      model.addP1(const Offset(10, 20));
      expect(model.isVisible, isTrue);
    });

    test('creates initial path with replace math', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(10, 20));
      expect(model.path1, isNotNull);
      expect(model.points.length, 1);
    });

    test('clears previous points', () {
      model.mode = SelectorMode.rectangle;
      model.points.addAll(<Offset>[Offset.zero, const Offset(5, 5)]);
      model.addP1(const Offset(10, 20));
      expect(model.points.length, 1);
    });

    test('does not create path1 with non-replace math', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.add;
      model.path1 = null;
      model.addP1(const Offset(10, 20));
      expect(model.path1, isNull);
    });
  });

  group('addP1 - circle mode', () {
    test('creates oval path with replace math', () {
      model.mode = SelectorMode.circle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(10, 20));
      expect(model.path1, isNotNull);
      expect(model.points.length, 1);
    });
  });

  group('addStraightLineRegionPoint', () {
    test('starts a multi-click region on the first point', () {
      model.mode = SelectorMode.line;
      final bool isClosed = model.addStraightLineRegionPoint(
        const Offset(10, 20),
        closeDistance: AppInteraction.selectionHandleSize,
      );

      expect(isClosed, isFalse);
      expect(model.path1, isNotNull);
      expect(model.points.length, 1);
    });

    test('adds vertices until the user clicks back near the first point', () {
      model.mode = SelectorMode.line;

      expect(
        model.addStraightLineRegionPoint(
          const Offset(10, 10),
          closeDistance: AppInteraction.selectionHandleSize,
        ),
        isFalse,
      );
      expect(
        model.addStraightLineRegionPoint(
          const Offset(60, 10),
          closeDistance: AppInteraction.selectionHandleSize,
        ),
        isFalse,
      );
      expect(
        model.addStraightLineRegionPoint(
          const Offset(60, 60),
          closeDistance: AppInteraction.selectionHandleSize,
        ),
        isFalse,
      );

      final bool isClosed = model.addStraightLineRegionPoint(
        const Offset(12, 12),
        closeDistance: AppInteraction.selectionHandleSize,
      );

      expect(isClosed, isTrue);
      expect(model.path1, isNotNull);
      expect(model.boundingRect, const Rect.fromLTWH(10, 10, 50, 50));
    });
  });

  group('updateStraightLineRegionPreview', () {
    test('extends the open edge to the hover position', () {
      model.mode = SelectorMode.line;
      model.addStraightLineRegionPoint(
        const Offset(10, 10),
        closeDistance: AppInteraction.selectionHandleSize,
      );
      model.addStraightLineRegionPoint(
        const Offset(60, 10),
        closeDistance: AppInteraction.selectionHandleSize,
      );

      model.updateStraightLineRegionPreview(
        const Offset(60, 60),
        closeDistance: AppInteraction.selectionHandleSize,
      );

      expect(model.path1, isNotNull);
      expect(model.boundingRect, const Rect.fromLTWH(10, 10, 50, 50));
    });
  });

  group('addP1 - lasso mode', () {
    test('appends point without clearing', () {
      model.mode = SelectorMode.lasso;
      model.addP1(const Offset(10, 20));
      model.addP1(const Offset(30, 40));
      expect(model.points.length, 2);
    });
  });

  group('addP1 - wand mode', () {
    test('does not create path', () {
      model.mode = SelectorMode.wand;
      model.addP1(const Offset(10, 20));
      expect(model.path1, isNull);
    });
  });

  group('addP2 - rectangle mode', () {
    test('creates rect path from two points with replace math', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(10, 10));
      model.addP2(const Offset(50, 50));

      expect(model.path1, isNotNull);
      final Rect bounds = model.boundingRect;
      expect(bounds.left, 10);
      expect(bounds.top, 10);
      expect(bounds.right, 50);
      expect(bounds.bottom, 50);
    });

    test('creates path2 with add math', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.add;
      model.addP1(const Offset(10, 10));
      model.addP2(const Offset(50, 50));

      expect(model.path2, isNotNull);
    });

    test('does nothing when points is empty', () {
      model.mode = SelectorMode.rectangle;
      model.addP2(const Offset(50, 50));
      expect(model.path1, isNull);
    });
  });

  group('addP2 - circle mode', () {
    test('creates oval path with replace math', () {
      model.mode = SelectorMode.circle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(10, 10));
      model.addP2(const Offset(50, 50));

      expect(model.path1, isNotNull);
      final Rect bounds = model.boundingRect;
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('creates path2 with remove math', () {
      model.mode = SelectorMode.circle;
      model.math = SelectorMath.remove;
      model.addP1(const Offset(10, 10));
      model.addP2(const Offset(50, 50));

      expect(model.path2, isNotNull);
    });
  });

  group('addP2 - lasso mode', () {
    test('builds polygon path from accumulated points', () {
      model.mode = SelectorMode.lasso;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(0, 0));
      model.addP2(const Offset(50, 0));
      model.addP2(const Offset(50, 50));
      model.addP2(const Offset(0, 50));

      expect(model.path1, isNotNull);
      final Rect bounds = model.boundingRect;
      expect(bounds.width, 50);
      expect(bounds.height, 50);
    });

    test('builds path2 with add math', () {
      model.mode = SelectorMode.lasso;
      model.math = SelectorMath.add;
      model.addP1(const Offset(0, 0));
      model.addP2(const Offset(50, 0));
      model.addP2(const Offset(50, 50));

      expect(model.path2, isNotNull);
    });
  });

  group('addP2 - wand mode', () {
    test('does nothing', () {
      model.mode = SelectorMode.wand;
      model.points.add(const Offset(10, 10));
      model.addP2(const Offset(50, 50));
      expect(model.path1, isNull);
    });
  });

  group('invert', () {
    test('inverts the selection within container', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(10, 10));
      model.addP2(const Offset(50, 50));

      const Rect container = Rect.fromLTWH(0, 0, 100, 100);
      model.invert(container);

      expect(model.path1, isNotNull);
      final Rect bounds = model.boundingRect;
      expect(bounds.width, greaterThanOrEqualTo(container.width - 1));
    });

    test('does nothing when path1 is null', () {
      model.invert(const Rect.fromLTWH(0, 0, 100, 100));
      expect(model.path1, isNull);
    });
  });

  group('translate', () {
    test('shifts the selection by offset', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(10, 10));
      model.addP2(const Offset(50, 50));

      final Rect before = model.boundingRect;
      model.translate(const Offset(20, 30));
      final Rect after = model.boundingRect;

      expect(after.left, closeTo(before.left + 20, 1));
      expect(after.top, closeTo(before.top + 30, 1));
    });

    test('does nothing for zero-size path', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(10, 10));
      // path1 is a zero-size rect
      model.translate(const Offset(20, 30));
      // Should not throw
    });
  });

  group('rotate', () {
    test('rotates path around center', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(0, 0));
      model.addP2(const Offset(100, 50));

      final Rect before = model.boundingRect;
      model.rotate(math.pi / 2);
      final Rect after = model.boundingRect;

      expect(after.width, closeTo(before.height, 2));
      expect(after.height, closeTo(before.width, 2));
    });

    test('does nothing when path1 is null', () {
      model.rotate(math.pi / 4);
      expect(model.path1, isNull);
    });

    test('rotates path2 when present', () {
      model.path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 50));
      model.path2 = Path()..addRect(const Rect.fromLTWH(10, 10, 30, 30));

      model.rotate(math.pi / 4);
      expect(model.path2, isNotNull);
    });
  });

  group('scaleUniform', () {
    test('scales the selection path evenly around its center', () {
      model.path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 50));

      model.scaleUniform(2);

      expect(model.boundingRect, const Rect.fromLTWH(-50, -25, 200, 100));
    });

    test('clamps scale factor to min', () {
      model.path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));

      model.scaleUniform(0.001);
      expect(model.path1, isNotNull);
    });

    test('clamps scale factor to max', () {
      model.path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));

      model.scaleUniform(100.0);
      expect(model.path1, isNotNull);
    });

    test('does nothing when path1 is null', () {
      model.scaleUniform(2.0);
      expect(model.path1, isNull);
    });

    test('scales path2 when present', () {
      model.path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
      model.path2 = Path()..addRect(const Rect.fromLTWH(10, 10, 30, 30));

      model.scaleUniform(1.5);
      expect(model.path2, isNotNull);
    });
  });

  group('nineGridResize', () {
    test('resizes path using handle', () {
      model.path1 = Path()..addRect(const Rect.fromLTWH(10, 10, 40, 40));

      final Rect before = model.boundingRect;
      model.nindeGridResize(NineGridHandle.right, const Offset(20, 0));
      final Rect after = model.boundingRect;

      expect(after.width, greaterThan(before.width));
    });

    test('does nothing when path1 is null', () {
      model.nindeGridResize(NineGridHandle.right, const Offset(20, 0));
      expect(model.path1, isNull);
    });
  });

  group('applyMath', () {
    test('replace math clears points', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(0, 0));
      model.addP2(const Offset(50, 50));

      model.applyMath();
      expect(model.points, isEmpty);
    });

    test('add math unions path1 and path2', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(0, 0));
      model.addP2(const Offset(50, 50));

      model.math = SelectorMath.add;
      model.addP1(const Offset(30, 30));
      model.addP2(const Offset(80, 80));

      model.applyMath();
      expect(model.path2, isNull);
      final Rect bounds = model.boundingRect;
      expect(bounds.right, closeTo(80, 1));
      expect(bounds.bottom, closeTo(80, 1));
    });

    test('remove math subtracts path2 from path1', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(0, 0));
      model.addP2(const Offset(100, 100));

      model.math = SelectorMath.remove;
      model.addP1(const Offset(25, 25));
      model.addP2(const Offset(75, 75));

      model.applyMath();
      expect(model.path2, isNull);
      expect(model.path1, isNotNull);
    });

    test('does nothing when path1 is null', () {
      model.math = SelectorMath.add;
      model.applyMath();
      expect(model.path1, isNull);
    });

    test('ignores non-finite add path input', () {
      model.mode = SelectorMode.rectangle;
      model.math = SelectorMath.replace;
      model.addP1(const Offset(0, 0));
      model.addP2(const Offset(50, 50));
      model.applyMath();

      final Rect before = model.boundingRect;

      model.math = SelectorMath.add;
      model.addP1(const Offset(30, 30));
      model.addP2(const Offset(double.nan, 80));

      model.applyMath();

      expect(model.path2, isNull);
      expect(model.boundingRect, before);
    });

    test('ignores combine failures during remove math', () {
      final SelectorModel throwingModel = _ThrowingCombineSelectorModel();
      throwingModel.mode = SelectorMode.rectangle;
      throwingModel.math = SelectorMath.replace;
      throwingModel.addP1(const Offset(0, 0));
      throwingModel.addP2(const Offset(100, 100));

      final Rect before = throwingModel.boundingRect;

      throwingModel.math = SelectorMath.remove;
      throwingModel.addP1(const Offset(25, 25));
      throwingModel.addP2(const Offset(75, 75));

      expect(throwingModel.applyMath, returnsNormally);
      expect(throwingModel.path2, isNull);
      expect(throwingModel.boundingRect, before);
    });
  });

  group('SelectorMode enum', () {
    test('has all expected values', () {
      expect(SelectorMode.values.length, 5);
      expect(
        SelectorMode.values,
        containsAll(<SelectorMode>[
          SelectorMode.rectangle,
          SelectorMode.circle,
          SelectorMode.line,
          SelectorMode.lasso,
          SelectorMode.wand,
        ]),
      );
    });
  });

  group('SelectorMath enum', () {
    test('has all expected values', () {
      expect(SelectorMath.values.length, 4);
      expect(
        SelectorMath.values,
        containsAll(<SelectorMath>[
          SelectorMath.replace,
          SelectorMath.add,
          SelectorMath.remove,
          SelectorMath.intersect,
        ]),
      );
    });
  });
}
