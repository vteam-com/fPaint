import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/updates/app_update_constants.dart';
import 'package:fpaint/updates/app_update_controller.dart';
import 'package:fpaint/updates/app_update_exception.dart';
import 'package:fpaint/updates/app_updater.dart';
import 'package:fpaint/widgets/update_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pub_semver/pub_semver.dart';

import '../helpers/widget_test_harness.dart';

AppUpdateController _controllerWithUpdate() {
  return AppUpdateController(
    updater: AppUpdater.forOperatingSystem(
      'linux',
      client: MockClient(
        (http.Request _) async => http.Response(
          jsonEncode(<String, Object?>{
            AppUpdates.jsonTagName: 'v9.0.0',
            AppUpdates.jsonAssets: <Object?>[
              <String, Object?>{
                AppUpdates.jsonAssetName: AppUpdates.linuxAsset,
                AppUpdates.jsonDownloadUrl: 'https://example.com/b',
              },
            ],
          }),
          HttpStatus.ok,
        ),
      ),
      // Not writable, so an install fails and shows its message.
      executable: '/nowhere/fpaint',
      processId: 1,
    ),
    runningVersion: Version(1, 0, 0),
  );
}

Widget _app(AppUpdateController? controller, {required Future<bool> Function(BuildContext) confirmQuit}) {
  final Widget button = UpdateButton(
    interactionProfile: AppInteractionProfiles.mouse,
    confirmQuit: confirmQuit,
  );
  return buildLocalizedTestApp(
    home: Scaffold(
      body: controller == null
          ? button
          : InheritedControllerScope<AppUpdateController>(controller: controller, child: button),
    ),
  );
}

void main() {
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('hidden without a controller or an update', (WidgetTester tester) async {
    await tester.pumpWidget(_app(null, confirmQuit: (_) async => true));
    expect(find.byKey(Keys.toolbarUpdateButton), findsNothing);

    await tester.pumpWidget(_app(_controllerWithUpdate(), confirmQuit: (_) async => true));
    expect(find.byKey(Keys.toolbarUpdateButton), findsNothing);
  });

  testWidgets('shows the update and reports a failed install', (WidgetTester tester) async {
    final AppUpdateController controller = _controllerWithUpdate();
    await tester.runAsync(controller.check);
    int confirmations = 0;
    await tester.pumpWidget(
      _app(
        controller,
        confirmQuit: (_) async {
          confirmations++;
          return true;
        },
      ),
    );
    expect(find.byKey(Keys.toolbarUpdateButton), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(Keys.toolbarUpdateButton));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(confirmations, 1);
    expect(find.text(l10n.updateFailed), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });

  test('every failure has a localized message', () {
    for (final AppUpdateFailure failure in AppUpdateFailure.values) {
      expect(updateFailureMessage(l10n, AppUpdateException(failure, '/x')), isNotEmpty);
    }
  });
}
