import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({
  required final AppPreferences preferences,
  required final AppProvider appProvider,
  required final ShellProvider shellProvider,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppPreferences>.value(value: preferences),
      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ChangeNotifierProvider<LayersProvider>.value(value: appProvider.layers),
      ChangeNotifierProvider<ShellProvider>.value(value: shellProvider),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox.expand(child: MainView())),
    ),
  );
}

void main() {
  late AppPreferences preferences;
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    shellProvider = ShellProvider();
  });

  testWidgets('shows and hides centered brush-size preview while brush size changes', (
    final WidgetTester tester,
  ) async {
    const Color activeColor = Color(0xFF123456);
    appProvider.brushColor = activeColor;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );

    appProvider.brushSize = 24.0;
    await tester.pump();

    final Finder previewFinder = find.byKey(Keys.brushSizePreviewOverlay);
    expect(previewFinder, findsOneWidget);
    final double expectedDiameter = 24.0 * appProvider.layers.scale;
    expect(tester.getSize(previewFinder), Size(expectedDiameter, expectedDiameter));

    final Finder mainViewFinder = find.byType(MainView);
    expect(tester.getCenter(previewFinder), tester.getCenter(mainViewFinder));
    expect(appProvider.brushSizePreviewColor, activeColor);

    await tester.pump(AppDefaults.brushSizePreviewDuration);
    await tester.pump();

    expect(find.byKey(Keys.brushSizePreviewOverlay), findsNothing);
  });
}
