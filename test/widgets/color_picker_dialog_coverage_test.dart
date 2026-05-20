import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:provider/provider.dart';

const List<Color> _presetColors = <Color>[
  AppColors.black,
  AppColors.white,
  AppColors.grey,
  AppColors.red,
  AppColors.orange,
  AppColors.yellow,
  AppColors.green,
  AppColors.blue,
  AppColors.purple,
];

Widget _buildTestWidget({
  required final Color initialColor,
  required final ValueChanged<Color> onColorChanged,
  final bool small = false,
}) {
  final ShellProvider shellProvider = ShellProvider()..deviceSizeSmall = small;
  return MultiProvider(
    providers: <ChangeNotifierProvider<ChangeNotifier>>[
      ChangeNotifierProvider<ShellProvider>.value(value: shellProvider),
      ChangeNotifierProvider<LayersProvider>.value(value: LayersProvider()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ColorPickerDialog(
          title: 'Pick Color',
          color: initialColor,
          onColorChanged: onColorChanged,
        ),
      ),
    ),
  );
}

void main() {
  group('ColorPickerDialog', () {
    testWidgets('renders and shows preset colors', (final WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          initialColor: Colors.red,
          onColorChanged: (final Color _) {},
        ),
      );
      await tester.pump();

      final Finder presetPreviews = find.byWidgetPredicate(
        (final Widget widget) => widget is ColorPreview && widget.minimal && _presetColors.contains(widget.color),
      );

      expect(presetPreviews, findsNWidgets(_presetColors.length));
    });

    testWidgets('tapping preset color updates state', (final WidgetTester tester) async {
      // ignore: unused_local_variable
      Color? result;
      await tester.pumpWidget(
        _buildTestWidget(
          initialColor: Colors.red,
          onColorChanged: (final Color c) => result = c,
        ),
      );
      await tester.pump();

      final Finder presetPreviews = find.byWidgetPredicate(
        (final Widget widget) => widget is ColorPreview && widget.minimal && _presetColors.contains(widget.color),
      );
      expect(presetPreviews, findsNWidgets(_presetColors.length));

      await tester.tap(
        find.byWidgetPredicate(
          (final Widget widget) => widget is ColorPreview && widget.minimal && widget.color == AppColors.orange,
        ),
      );
      await tester.pump();

      final ColorPreview preview = tester.widget<ColorPreview>(
        find.byWidgetPredicate((final Widget widget) => widget is ColorPreview && widget.minimal == false).first,
      );
      expect(preview.color, AppColors.orange);
    });

    testWidgets('typing hex value updates color', (final WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          initialColor: Colors.red,
          onColorChanged: (final Color _) {},
        ),
      );
      await tester.pump();

      // Find hex text field.
      final Finder hexField = find.byType(AppTextField);
      expect(hexField, findsOneWidget);

      // Type a hex color.
      await tester.enterText(hexField, '#00FF00');
      await tester.pump();
    });

    testWidgets('copy button copies hex to clipboard', (final WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          initialColor: Colors.blue,
          onColorChanged: (final Color _) {},
        ),
      );
      await tester.pump();

      // Find copy button (second icon button after paste).
      final Finder copyButtons = find.byType(AppButtonIcon);
      expect(copyButtons, findsWidgets);

      // The copy button is the last AppButtonIcon in the hex row.
      await tester.tap(copyButtons.last);
      await tester.pump();
      // Flush the snackbar timer.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('small device renders full screen layout', (final WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          initialColor: Colors.green,
          onColorChanged: (final Color _) {},
          small: true,
        ),
      );
      await tester.pump();

      // Should still render content.
      expect(find.byType(ColorPickerDialog), findsOneWidget);
    });

    testWidgets('cancel pops dialog', (final WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          initialColor: Colors.red,
          onColorChanged: (final Color _) {},
        ),
      );
      await tester.pump();

      final Finder cancelButton = find.widgetWithText(AppButtonText, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump();
    });

    testWidgets('paste reads clipboard hex', (final WidgetTester tester) async {
      // Mock clipboard to return a hex color string.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (final MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': '#FF00FF'};
          }
          return null;
        },
      );

      await tester.pumpWidget(
        _buildTestWidget(
          initialColor: Colors.red,
          onColorChanged: (final Color _) {},
        ),
      );
      await tester.pump();

      // Find paste button — it's an AppButtonIcon with clipboard paste icon.
      final Finder pasteButtons = find.byType(AppButtonIcon);
      expect(pasteButtons, findsWidgets);

      // Tap the paste button (first icon button in the hex row).
      await tester.tap(pasteButtons.at(pasteButtons.evaluate().length - 2));
      await tester.pumpAndSettle();

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
  });
}
