import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/quit_confirmation.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/material_free.dart';

import '../helpers/layers_provider_test_helper.dart';

Widget _buildHost({required void Function(BuildContext) onContext}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Localizations(
        locale: const Locale('en'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Navigator(
          onGenerateRoute: (RouteSettings settings) {
            return PageRouteBuilder<void>(
              settings: settings,
              pageBuilder: (BuildContext context, Animation<double> _, Animation<double> _) {
                onContext(context);
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a clean document quits without prompting', (WidgetTester tester) async {
    final LayersProvider layers = createInitializedLayersProvider();
    late BuildContext hostContext;

    await tester.pumpWidget(_buildHost(onContext: (BuildContext context) => hostContext = context));

    final bool shouldQuit = await confirmQuitWithUnsavedChanges(
      layers: layers,
      context: hostContext,
    );
    await tester.pumpAndSettle();

    expect(shouldQuit, isTrue);
    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('a dirty document prompts and cancelling blocks the quit', (WidgetTester tester) async {
    final LayersProvider layers = createInitializedLayersProvider()..markAllChanged();
    late BuildContext hostContext;

    await tester.pumpWidget(_buildHost(onContext: (BuildContext context) => hostContext = context));

    final Future<bool> pendingQuit = confirmQuitWithUnsavedChanges(
      layers: layers,
      context: hostContext,
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await pendingQuit, isFalse);
  });

  testWidgets('a dirty document quits when the user discards the changes', (WidgetTester tester) async {
    final LayersProvider layers = createInitializedLayersProvider()..markAllChanged();
    late BuildContext hostContext;

    await tester.pumpWidget(_buildHost(onContext: (BuildContext context) => hostContext = context));

    final Future<bool> pendingQuit = confirmQuitWithUnsavedChanges(
      layers: layers,
      context: hostContext,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quit Without Saving'));
    await tester.pumpAndSettle();

    expect(await pendingQuit, isTrue);
  });

  testWidgets('a missing context allows the quit rather than trapping the user', (WidgetTester tester) async {
    final LayersProvider layers = createInitializedLayersProvider()..markAllChanged();

    expect(
      await confirmQuitWithUnsavedChanges(layers: layers, context: null),
      isTrue,
    );
  });
}
