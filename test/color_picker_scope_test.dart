import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';

/// Regression test: the color picker is shown via a bottom sheet that
/// [showGeneralDialog] roots at the app navigator — above the
/// [InheritedControllerScope] the editor inserts. `showColorPicker` must capture
/// the [LayersProvider] from the (in-scope) call site and re-provide it into the
/// sheet subtree, otherwise `LayersProvider.of` inside the dialog throws
/// `No InheritedControllerScope<LayersProvider> found in context`.
void main() {
  testWidgets('color picker resolves LayersProvider when opened from the '
      'editor scope via an overlay', (final WidgetTester tester) async {
    final LayersProvider layers = LayersProvider(undoProvider: UndoProvider());
    addTearDown(layers.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InheritedControllerScope<LayersProvider>(
          controller: layers,
          child: Builder(
            builder: (final BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showColorPicker(
                    context: context,
                    title: 'Pick',
                    color: const Color(0xFF112233),
                    onSelectedColor: (final Color _) {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The dialog built without throwing — the scope was re-provided across the
    // overlay boundary.
    expect(tester.takeException(), isNull);
    expect(find.byType(ColorPickerDialog), findsOneWidget);
  });
}
