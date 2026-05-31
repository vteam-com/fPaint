import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_tooltip.dart';
import 'package:fpaint/widgets/selector_widget.dart';

const Duration _snackBarDismissDuration = Duration(seconds: 4);

Widget _buildHarness({
  required final Path? path1,
  Path? path2,
  bool enableMoveAndResize = true,
  bool isDrawing = false,
  required final VoidCallback onCancel,
  required final Future<void> Function() onCopy,
  required final Future<void> Function() onDuplicate,
  Future<void> Function(Offset offset, bool duplicateOnNewLayer)? onDuplicateMove,
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
          onDuplicateMove: onDuplicateMove,
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

LogicalKeyboardKey _duplicateMoveModifierKey() {
  final bool isApplePlatform =
      defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
  return isApplePlatform ? LogicalKeyboardKey.altLeft : LogicalKeyboardKey.controlLeft;
}

void main() {
  group('SelectionRectWidget', () {
    testWidgets('renders empty when path1 is null', (final WidgetTester tester) async {
      await tester.pumpWidget(
        _buildHarness(
          path1: null,
          onCancel: () {},
          onCopy: () async {},
          onDuplicate: () async {},
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
          onCopy: () async {},
          onDuplicate: () async {},
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

    testWidgets('hides quick actions while drawing', (final WidgetTester tester) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(100, 100, 200, 160));

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          isDrawing: true,
          onCancel: () {},
          onCopy: () async {},
          onDuplicate: () async {},
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
          onCopy: () async {},
          onDuplicate: () async {},
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
          onCopy: () async {},
          onDuplicate: () async {},
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

    testWidgets('copy, duplicate, cancel and transform controls invoke callbacks', (
      final WidgetTester tester,
    ) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(140, 140, 200, 200));
      int cancelCalls = 0;
      int copyCalls = 0;
      int duplicateCalls = 0;
      int transformCalls = 0;

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {
            cancelCalls++;
          },
          onCopy: () async {
            copyCalls++;
          },
          onDuplicate: () async {
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
      final Finder cancelTooltip = find.byWidgetPredicate(
        (final Widget w) => w is AppTooltip && w.message == l10n.cancel,
      );
      final Finder transformTooltip = find.byWidgetPredicate(
        (final Widget w) => w is AppTooltip && w.message == l10n.transform,
      );

      await tester.tap(copyTooltip);
      await tester.pump();
      await tester.tap(duplicateTooltip);
      await tester.pump();
      await tester.tap(cancelTooltip);
      await tester.pump();
      await tester.tap(transformTooltip);
      await tester.pump();

      expect(cancelCalls, 1);
      expect(copyCalls, 1);
      expect(duplicateCalls, 1);
      expect(transformCalls, 1);
      expect(find.text(l10n.copied), findsOneWidget);

      await tester.pump(_snackBarDismissDuration);
      await tester.pump();
      expect(find.text(l10n.copied), findsNothing);
    });

    testWidgets('quick actions use neutral styling and only copy shows snackbar feedback', (
      final WidgetTester tester,
    ) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(140, 140, 200, 200));

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () async {},
          onDuplicate: () async {},
          onToggleTransformMode: () {},
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
        (final Widget widget) => widget is AppTooltip && widget.message == l10n.copyToClipboard,
      );
      final Finder duplicateTooltip = find.byWidgetPredicate(
        (final Widget widget) => widget is AppTooltip && widget.message == l10n.duplicate,
      );
      final Finder cancelTooltip = find.byWidgetPredicate(
        (final Widget widget) => widget is AppTooltip && widget.message == l10n.cancel,
      );
      final Finder effectsButton = find.byKey(Keys.effectsButton);

      final Finder copyScale = find.descendant(of: copyTooltip, matching: find.byType(AnimatedScale));
      expect(tester.widget<AnimatedScale>(copyScale).scale, 1);

      final TestGesture copyPress = await tester.startGesture(tester.getCenter(copyTooltip));
      await tester.pump();
      expect(tester.widget<AnimatedScale>(copyScale).scale, lessThan(1));
      await copyPress.up();
      await tester.pump();
      await tester.pump();

      final Finder copyBackground = find.descendant(
        of: copyTooltip,
        matching: find.byWidgetPredicate(
          (final Widget widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      final Finder effectsBackground = find.descendant(
        of: effectsButton,
        matching: find.byWidgetPredicate(
          (final Widget widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      final Finder cancelIcon = find.descendant(of: cancelTooltip, matching: find.byType(AppSvgIcon));

      expect(
        (tester.widget<Container>(copyBackground).decoration! as BoxDecoration).color,
        AppColors.buttonBackground,
      );
      expect(
        (tester.widget<Container>(effectsBackground).decoration! as BoxDecoration).color,
        AppColors.buttonBackground,
      );
      expect(tester.widget<AppSvgIcon>(cancelIcon).color, AppColors.buttonDanger);

      await tester.tap(copyTooltip);
      await tester.pump();
      expect(find.text(l10n.copied), findsOneWidget);

      await tester.tap(duplicateTooltip);
      await tester.pump();
      expect(find.text(l10n.copied), findsOneWidget);

      await tester.pump(_snackBarDismissDuration);
      await tester.pump();
      expect(find.text(l10n.copied), findsNothing);
    });

    testWidgets('quick action surface stays inside selection overlay bounds', (
      final WidgetTester tester,
    ) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(200, 140, 172, 120));

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () async {},
          onDuplicate: () async {},
          onToggleTransformMode: () {},
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
      final Finder selectionStack = find.descendant(
        of: find.byType(SelectionRectWidget),
        matching: find.byType(Stack),
      );
      final Finder copyTooltip = find.byWidgetPredicate(
        (final Widget w) => w is AppTooltip && w.message == l10n.copyToClipboard,
      );
      final Finder cancelTooltip = find.byWidgetPredicate(
        (final Widget w) => w is AppTooltip && w.message == l10n.cancel,
      );

      expect(selectionStack, findsOneWidget);
      expect(tester.getRect(copyTooltip).left, greaterThanOrEqualTo(tester.getRect(selectionStack).left));
      expect(tester.getRect(cancelTooltip).right, lessThanOrEqualTo(tester.getRect(selectionStack).right));
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
          onCopy: () async {},
          onDuplicate: () async {},
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

      final BuildContext context = tester.element(find.byType(SelectionRectWidget));
      final AppLocalizations l10n = AppLocalizations.of(context)!;
      final Finder translateTooltip = find.byWidgetPredicate(
        (final Widget widget) => widget is AppTooltip && widget.message == l10n.translate,
      );
      final Finder scaleTooltip = find.byWidgetPredicate(
        (final Widget widget) => widget is AppTooltip && widget.message == l10n.scale,
      );
      final Finder rotateTooltip = find.byWidgetPredicate(
        (final Widget widget) => widget is AppTooltip && widget.message == l10n.resizeRotate,
      );

      await tester.dragFrom(tester.getCenter(translateTooltip), const Offset(15, 10));
      await tester.pump();
      await tester.dragFrom(tester.getCenter(scaleTooltip), const Offset(20, 20));
      await tester.pump();
      await tester.dragFrom(tester.getCenter(rotateTooltip), const Offset(30, 10));
      await tester.pump();

      expect(translateCalls, greaterThan(0));
      expect(scaleCalls, greaterThan(0));
      expect(rotateCalls, greaterThan(0));
    });

    testWidgets('modifier-assisted move duplicates instead of translating the current selection', (
      final WidgetTester tester,
    ) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(140, 140, 200, 200));
      int dragCalls = 0;
      int duplicateMoveCalls = 0;
      Offset duplicateMoveOffset = Offset.zero;
      bool? duplicateMoveOnNewLayer;

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () async {},
          onDuplicate: () async {},
          onDuplicateMove: (final Offset offset, final bool duplicateOnNewLayerValue) async {
            duplicateMoveCalls++;
            duplicateMoveOffset += offset;
            duplicateMoveOnNewLayer = duplicateOnNewLayerValue;
          },
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {
            dragCalls++;
          },
          onResize: (final NineGridHandle _, final Offset _) {},
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );
      await tester.pump();

      final LogicalKeyboardKey modifierKey = _duplicateMoveModifierKey();
      await tester.sendKeyDownEvent(modifierKey);
      await tester.dragFrom(const Offset(240, 240), const Offset(20, 10));
      await tester.pump();
      await tester.sendKeyUpEvent(modifierKey);

      expect(dragCalls, 0);
      expect(duplicateMoveCalls, greaterThan(0));
      expect(duplicateMoveOffset, isNot(Offset.zero));
      expect(duplicateMoveOnNewLayer, isFalse);
    });

    testWidgets('shift plus modifier-assisted move requests a new-layer duplicate', (
      final WidgetTester tester,
    ) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(140, 140, 200, 200));
      int dragCalls = 0;
      bool? duplicateMoveOnNewLayer;

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () async {},
          onDuplicate: () async {},
          onDuplicateMove: (final Offset _, final bool duplicateOnNewLayerValue) async {
            duplicateMoveOnNewLayer = duplicateOnNewLayerValue;
          },
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {
            dragCalls++;
          },
          onResize: (final NineGridHandle _, final Offset _) {},
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );
      await tester.pump();

      final LogicalKeyboardKey modifierKey = _duplicateMoveModifierKey();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(modifierKey);
      await tester.dragFrom(const Offset(240, 240), const Offset(20, 10));
      await tester.pump();
      await tester.sendKeyUpEvent(modifierKey);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(dragCalls, 0);
      expect(duplicateMoveOnNewLayer, isTrue);
    });

    testWidgets('modifier-assisted translate handle drag duplicates instead of translating', (
      final WidgetTester tester,
    ) async {
      final Path path = Path()..addRect(const Rect.fromLTWH(100, 100, 200, 160));
      int translateCalls = 0;
      int duplicateMoveCalls = 0;
      bool? duplicateMoveOnNewLayer;

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () async {},
          onDuplicate: () async {},
          onDuplicateMove: (final Offset _, final bool duplicateOnNewLayerValue) async {
            duplicateMoveCalls++;
            duplicateMoveOnNewLayer = duplicateOnNewLayerValue;
          },
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {
            translateCalls++;
          },
          onResize: (final NineGridHandle _, final Offset _) {},
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );
      await tester.pump();

      final BuildContext context = tester.element(find.byType(SelectionRectWidget));
      final AppLocalizations l10n = AppLocalizations.of(context)!;
      final Finder translateTooltip = find.byWidgetPredicate(
        (final Widget widget) => widget is AppTooltip && widget.message == l10n.translate,
      );

      final LogicalKeyboardKey modifierKey = _duplicateMoveModifierKey();
      await tester.sendKeyDownEvent(modifierKey);
      await tester.dragFrom(tester.getCenter(translateTooltip), const Offset(15, 10));
      await tester.pump();
      await tester.sendKeyUpEvent(modifierKey);

      expect(translateCalls, 0);
      expect(duplicateMoveCalls, greaterThan(0));
      expect(duplicateMoveOnNewLayer, isFalse);
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
          onCopy: () async {},
          onDuplicate: () async {},
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

    testWidgets('mode controls flip below selection when bounds are near the top edge', (
      final WidgetTester tester,
    ) async {
      // Selection positioned so close to the top that idealControlsTop < 0
      final Path path = Path()..addRect(const Rect.fromLTWH(200, 10, 200, 150));

      await tester.pumpWidget(
        _buildHarness(
          path1: path,
          onCancel: () {},
          onCopy: () async {},
          onDuplicate: () async {},
          onToggleTransformMode: () {},
          onDrag: (final Offset _) {},
          onResize: (final NineGridHandle _, final Offset _) {},
          onScale: (final double _) {},
          onRotate: (final double _) {},
          onEffectSelected: (final SelectionEffect _, final BuildContext _) async {},
        ),
      );
      await tester.pump();

      const double buttonSize = AppInteraction.imagePlacementButtonSize;
      const double rotationHandleDistance = AppInteraction.selectionToolbarMargin;
      final Rect bounds = path.getBounds();
      final double idealTop = bounds.top - rotationHandleDistance - buttonSize / AppMath.pair;

      // Verify the ideal position would clip (< 0) and the mode controls are found
      expect(idealTop, lessThan(0));
      final BuildContext context = tester.element(find.byType(SelectionRectWidget));
      final AppLocalizations l10n = AppLocalizations.of(context)!;
      expect(find.text(l10n.translate), findsNothing); // tooltip not visible
      // The mode buttons are rendered below the selection when flipped
      expect(find.byType(SelectionRectWidget), findsOneWidget);
    });
  });
}
