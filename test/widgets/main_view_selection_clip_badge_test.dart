import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/draft_flusher.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

class _NoopDraftFlusher implements DraftFlusher {
  @override
  Future<void> flushNow() async {}
}

Widget _buildHarness({
  required final AppPreferences preferences,
  required final AppProvider appProvider,
  required final ShellProvider shellProvider,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<DraftFlusher>.value(value: _NoopDraftFlusher()),
      ChangeNotifierProvider<AppPreferences>.value(value: preferences),
      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ChangeNotifierProvider<LayersProvider>.value(value: appProvider.layers),
      ChangeNotifierProvider<ShellProvider>.value(value: shellProvider),
    ],
    child: buildLocalizedTestApp(
      home: const Scaffold(body: SizedBox.expand(child: MainView())),
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

  testWidgets('shows the clip badge on a gesture tool with an active selection and clears it', (
    final WidgetTester tester,
  ) async {
    appProvider.selectedAction = ActionType.brush;
    appProvider.selectAll();

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    expect(find.byKey(Keys.selectionClipBadge), findsOneWidget);
    expect(appProvider.selectorModel.isVisible, isTrue);

    await tester.tap(find.byKey(Keys.selectionClipBadgeClear));
    await tester.pump();

    expect(appProvider.selectorModel.isVisible, isFalse);
    expect(find.byKey(Keys.selectionClipBadge), findsNothing);
  });

  testWidgets('hides the clip badge while the selector tool is active', (final WidgetTester tester) async {
    appProvider.activateSelectionAction();
    appProvider.selectAll();

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    expect(appProvider.selectorModel.isVisible, isTrue);
    expect(appProvider.selectedAction, ActionType.selector);
    expect(find.byKey(Keys.selectionClipBadge), findsNothing);
  });
}
