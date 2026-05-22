import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/app_tooltip.dart';
import 'package:fpaint/widgets/selector_widget.dart';

Widget _buildHarness({
  required final Path? path1,
  Path? path2,
  bool enableMoveAndResize = true,
  bool isDrawing = false,
  required final VoidCallback onCancel,
  required final VoidCallback onCopy,
  required final VoidCallback onDuplicate,
  required final VoidCallback onToggleTransformMode,
  required final void Function(Offset) onDrag,
  required final void Function(NineGridHandle, Offset) onResize,
  required final void Function(double) onScale,
  required final void Function(double) onRotate,
  required final Future<void> Function(SelectionEffect effect, BuildContext context) onEffectSelected,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(size: Size(1200, 900)),
        child: SelectionRectWidget(
          path1: path1,
          path2: path2,
          enableMoveAndResize: enableMoveAndResize,
          isDrawing: isDrawing,
          onCancel: onCancel,
          onCopy: onCopy,
          onDuplicate: onDuplicate,
          onToggleTransformMode: onToggleTransformMode,
          onDrag: onDrag,
          onResize: onResize,
          onScale: onScale,
          onRotate: onRotate,
          onEffectSelected: onEffectSelected,
        ),
      ),
    ),
  );
}

void main() {
  group('SelectionRectWidget', () {
    testWidgets('renders empty when path1 is null', (final WidgetTester tester) async {
      await tester.pumpWidget(
        _buildHarness(
          path1: null,
          onCancel: () {},
          onCopy: () {},
          onDuplicate: () {},
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {},
          onResize: (final NineGridHandle _, final Offset _) {},
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );

      expect(find.byKey(Keys.effectsButton), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('shows effect button when not drawing and move/resize enabled', (final WidgetTester tester) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(100, 100, 200, 160));

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () {},
          onDuplicate: () {},
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {},
          onResize: (final NineGridHandle _, final Offset _) {},
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );
      await tester.pump();

      expect(find.byKey(Keys.effectsButton), findsOneWidget);
    });

    testWidgets('hides bottom controls while drawing', (final WidgetTester tester) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(100, 100, 200, 160));

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          isDrawing: true,
          onCancel: () {},
          onCopy: () {},
          onDuplicate: () {},
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {},
          onResize: (final NineGridHandle _, final Offset _) {},
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );
      await tester.pump();

      expect(find.byKey(Keys.effectsButton), findsNothing);
    });

    testWidgets('effect menu selection calls onEffectSelected callback', (final WidgetTester tester) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(120, 90, 180, 140));
      SelectionEffect? selected;

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () {},
          onDuplicate: () {},
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {},
          onResize: (final NineGridHandle _, final Offset _) {},
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect effect, final BuildContext _) async {
            selected = effect;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.effectsButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final BuildContext context = tester.element(find.byType(SelectionRectWidget));
      final AppLocalizations l10n = AppLocalizations.of(context)!;
      final String firstLabel = effectLabel(l10n, SelectionEffect.values.first);

      expect(find.text(firstLabel), findsWidgets);
      await tester.tap(find.text(firstLabel).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(selected, SelectionEffect.values.first);
    });

    testWidgets('move and resize callbacks are callable by gestures', (final WidgetTester tester) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(140, 140, 200, 200));
      int dragCalls = 0;
      int resizeCalls = 0;

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () {},
          onDuplicate: () {},
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {
            dragCalls++;
          },
          onResize: (final NineGridHandle _, final Offset _) {
            resizeCalls++;
          },
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );
      await tester.pump();

      // Drag at center should hit the move handle.
      await tester.dragFrom(const Offset(240, 240), const Offset(20, 10));
      await tester.pump();

      // Drag at top-left corner should hit one resize handle.
      await tester.dragFrom(const Offset(140, 140), const Offset(-15, -10));
      await tester.pump();

      expect(dragCalls + resizeCalls, greaterThan(0));
    });

    testWidgets('copy, duplicate and transform controls invoke callbacks', (final WidgetTester tester) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(140, 140, 200, 200));
      int copyCalls = 0;
      int duplicateCalls = 0;
      int transformCalls = 0;

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () {
            copyCalls++;
          },
          onDuplicate: () {
            duplicateCalls++;
          },
          onToggleTransformMode: () {
            transformCalls++;
          },
          onDrag: (final Offset _) {},
          onResize: (final NineGridHandle _, final Offset _) {},
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );
      await tester.pump();

      final BuildContext context = tester.element(find.byType(SelectionRectWidget));
      final AppLocalizations l10n = AppLocalizations.of(context)!;

      final Finder copyTooltip = find.byWidgetPredicate(
        (final Widget w) => w is AppTooltip && w.message == l10n.copyToClipboard,
      );
      final Finder duplicateTooltip = find.byWidgetPredicate(
        (final Widget w) => w is AppTooltip && w.message == l10n.duplicate,
      );
      final Finder transformTooltip = find.byWidgetPredicate(
        (final Widget w) => w is AppTooltip && w.message == l10n.transform,
      );

      await tester.tap(copyTooltip);
      await tester.pump();
      await tester.tap(duplicateTooltip);
      await tester.pump();
      await tester.tap(transformTooltip);
      await tester.pump();

      expect(copyCalls, 1);
      expect(duplicateCalls, 1);
      expect(transformCalls, 1);
    });

    testWidgets('translate, scale and rotate handle drags invoke callbacks', (final WidgetTester tester) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(100, 100, 200, 160));
      int translateCalls = 0;
      int scaleCalls = 0;
      int rotateCalls = 0;

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () {},
          onDuplicate: () {},
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {
            translateCalls++;
          },
          onResize: (final NineGridHandle _, final Offset _) {},
          onScale: (final double _) {
            scaleCalls++;
          },
          onRotate: (final double _) {
            rotateCalls++;
          },
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );
      await tester.pump();

      final Rect bounds = path.getBounds();
      const double buttonSize = AppInteraction.imagePlacementButtonSize;
      const double spacing = AppInteraction.imagePlacementButtonSpacing;
      const double controlsWidth = buttonSize * AppMath.four + spacing * AppMath.triple;
      final double controlsTop = bounds.top - AppInteraction.rotationHandleDistance - buttonSize / AppMath.pair;
      final double controlsLeft = bounds.center.dx - controlsWidth / AppMath.pair;

      final Offset translateCenter = Offset(
        controlsLeft + buttonSize / AppMath.pair,
        controlsTop + buttonSize / AppMath.pair,
      );

      final Offset scaleCenter = Offset(
        controlsLeft + buttonSize + spacing + buttonSize / AppMath.pair,
        controlsTop + buttonSize / AppMath.pair,
      );
      final Offset rotateCenter = Offset(
        controlsLeft + (buttonSize + spacing) * AppMath.pair + buttonSize / AppMath.pair,
        controlsTop + buttonSize / AppMath.pair,
      );

      await tester.dragFrom(translateCenter, const Offset(15, 10));
      await tester.pump();
      await tester.dragFrom(scaleCenter, const Offset(20, 20));
      await tester.pump();
      await tester.dragFrom(rotateCenter, const Offset(30, 10));
      await tester.pump();

      expect(translateCalls, greaterThan(0));
      expect(scaleCalls, greaterThan(0));
      expect(rotateCalls, greaterThan(0));
    });

    testWidgets('supports secondary path while move/resize is disabled', (final WidgetTester tester) async {
      final Path path1 = Path()..addRect(const Rect.fromLTWH(80, 80, 180, 120));
      final Path path2 = Path()..addRect(const Rect.fromLTWH(110, 110, 90, 60));
      int dragCalls = 0;
      int resizeCalls = 0;

      await tester.pumpWidget(
        _buildHarness(
          path1: path1,
          path2: path2,
          enableMoveAndResize: false,
          onCancel: () {},
          onCopy: () {},
          onDuplicate: () {},
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {
            dragCalls++;
          },
          onResize: (final NineGridHandle _, final Offset _) {
            resizeCalls++;
          },
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );
      await tester.pump();

      // With move/resize disabled, drag gestures should not call callbacks.
      await tester.dragFrom(const Offset(170, 140), const Offset(20, 20));
      await tester.pump();

      expect(find.byKey(Keys.effectsButton), findsNothing);
      expect(dragCalls, 0);
      expect(resizeCalls, 0);
    });
  });
}
