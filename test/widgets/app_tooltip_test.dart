import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/app_tooltip.dart';
import 'package:material_ui/material_ui.dart';

/// The yellow Flutter underlines text with when it falls back to
/// [WidgetsApp.textStyle] for want of a [DefaultTextStyle] ancestor. MaterialApp
/// sets that fallback to a "consider putting your text in a Material" style
/// drawn with a doubled yellow underline.
const Color _debugFallbackUnderline = Color(0xFFFFFF00);

Widget _buildTooltipTestApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

/// Hovers the tooltip's child so the overlay entry is inserted.
Future<void> _hover(WidgetTester tester, Finder target) async {
  final TestGesture pointer = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await pointer.addPointer(location: Offset.zero);
  addTearDown(pointer.removePointer);
  await pointer.moveTo(tester.getCenter(target));
  await tester.pump();
}

void main() {
  testWidgets('a hovered tooltip shows its message', (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildTooltipTestApp(
        child: const AppTooltip(
          message: 'brush',
          child: SizedBox.square(dimension: 40),
        ),
      ),
    );

    expect(find.text('brush'), findsNothing);
    await _hover(tester, find.byType(AppTooltip));
    expect(find.text('brush'), findsOneWidget);
  });

  testWidgets('tooltip text is styled, not left to the debug fallback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTooltipTestApp(
        child: const AppTooltip(
          // The undo/redo history tooltip is many lines of action names.
          message: 'brush\nblur\nline (⌘ + Z)',
          child: SizedBox.square(dimension: 40),
        ),
      ),
    );
    await _hover(tester, find.byType(AppTooltip));

    final TextStyle painted = tester
        .widget<RichText>(
          find.descendant(
            of: find.text('brush\nblur\nline (⌘ + Z)'),
            matching: find.byType(RichText),
          ),
        )
        .text
        .style!;

    // An overlay entry is its own tree root, so without an explicit
    // DefaultTextStyle this text fell back to MaterialApp's "put me in a
    // Material" style and rendered with doubled yellow underlines.
    expect(painted.decoration, isNot(TextDecoration.underline));
    expect(painted.decorationColor, isNot(_debugFallbackUnderline));
    expect(painted.color, AppTextStyle.label.color);
    expect(painted.fontSize, AppTextStyle.label.fontSize);
  });

  testWidgets('the tooltip goes away when the pointer leaves', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTooltipTestApp(
        child: const AppTooltip(
          message: 'brush',
          child: SizedBox.square(dimension: 40),
        ),
      ),
    );

    final TestGesture pointer = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(find.byType(AppTooltip)));
    await tester.pump();
    expect(find.text('brush'), findsOneWidget);

    await pointer.moveTo(const Offset(1000, 1000));
    await tester.pump();
    expect(find.text('brush'), findsNothing);
  });
}
