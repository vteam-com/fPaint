import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/app_update_exception.dart';
import 'package:fpaint/updates/app_release.dart';
import 'package:fpaint/updates/app_update_constants.dart';
import 'package:fpaint/updates/app_update_controller.dart';
import 'package:fpaint/updates/app_updater.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

const String _downloadUrl = 'https://example.com/build';

Map<String, Object?> _releaseJson(String tag, String asset) => <String, Object?>{
  AppUpdates.jsonTagName: tag,
  AppUpdates.jsonAssets: <Object?>[
    <String, Object?>{AppUpdates.jsonAssetName: 'other.zip', AppUpdates.jsonDownloadUrl: 'https://example.com/x'},
    <String, Object?>{AppUpdates.jsonAssetName: asset, AppUpdates.jsonDownloadUrl: _downloadUrl},
  ],
};

/// Records the commands an updater runs and starts.
class _Processes {
  final List<List<String>> ran = <List<String>>[];
  final List<List<String>> started = <List<String>>[];
  int exitCode = 0;

  /// Creates [onRun]'s folder as an unpack would.
  void Function(List<String> arguments)? onRun;

  Future<ProcessResult> run(String executable, List<String> arguments) async {
    ran.add(<String>[executable, ...arguments]);
    onRun?.call(arguments);
    return ProcessResult(0, exitCode, '', 'boom');
  }

  Future<Process> start(String executable, List<String> arguments, {ProcessStartMode mode = ProcessStartMode.normal}) {
    started.add(<String>[executable, ...arguments]);
    return Process.start('true', <String>[]);
  }
}

void main() {
  group('AppRelease', () {
    test('reads the version and the matching asset', () {
      final AppRelease? release = AppRelease.fromGitHub(
        _releaseJson('v2.3.0', AppUpdates.linuxAsset),
        AppUpdates.linuxAsset,
      );
      expect(release?.version, Version(2, 3, 0));
      expect(release?.downloadUrl, Uri.parse(_downloadUrl));
    });

    test('is null without the asset, with a bad tag, or bad json', () {
      expect(AppRelease.fromGitHub(_releaseJson('v2.3.0', 'x'), AppUpdates.linuxAsset), isNull);
      expect(AppRelease.fromGitHub(_releaseJson('2.3.0', AppUpdates.linuxAsset), AppUpdates.linuxAsset), isNull);
      expect(AppRelease.fromGitHub(_releaseJson('vnope', AppUpdates.linuxAsset), AppUpdates.linuxAsset), isNull);
      expect(AppRelease.fromGitHub('nope', AppUpdates.linuxAsset), isNull);
    });
  });

  group('AppUpdater', () {
    late Directory install;
    late _Processes processes;

    setUp(() async {
      install = await Directory.systemTemp.createTemp('fpaint_update_test_');
      processes = _Processes();
    });

    tearDown(() async {
      if (install.existsSync()) {
        await install.delete(recursive: true);
      }
    });

    AppUpdater updaterFor(String os, http.Client client, {String? executable}) => AppUpdater.forOperatingSystem(
      os,
      client: client,
      executable: executable ?? p.join(install.path, 'fpaint'),
      processId: 42,
      run: processes.run,
      start: processes.start,
    )!;

    test('forOperatingSystem picks each desktop and none elsewhere', () {
      final MockClient client = MockClient((http.Request _) async => http.Response('', HttpStatus.ok));
      expect(updaterFor('macos', client), isA<MacAppUpdater>());
      expect(updaterFor('windows', client), isA<WindowsAppUpdater>());
      expect(updaterFor('linux', client), isA<LinuxAppUpdater>());
      expect(AppUpdater.forOperatingSystem('ios', client: client, executable: '', processId: 1), isNull);
    });

    test('latestRelease parses GitHub and reports HTTP errors', () async {
      final MockClient ok = MockClient(
        (http.Request _) async =>
            http.Response(jsonEncode(_releaseJson('v9.0.0', AppUpdates.linuxAsset)), HttpStatus.ok),
      );
      expect((await updaterFor('linux', ok).latestRelease())?.version, Version(9, 0, 0));

      final MockClient failing = MockClient((http.Request _) async => http.Response('', HttpStatus.forbidden));
      await expectLater(
        updaterFor('linux', failing).latestRelease(),
        throwsA(
          isA<AppUpdateException>().having((AppUpdateException e) => e.failure, 'failure', AppUpdateFailure.network),
        ),
      );

      final MockClient offline = MockClient((http.Request _) async => throw const SocketException('offline'));
      await expectLater(updaterFor('linux', offline).latestRelease(), throwsA(isA<AppUpdateException>()));
    });

    test('stage downloads, unpacks and starts the Linux replacer', () async {
      final MockClient client = MockClient((http.Request _) async => http.Response('archive', HttpStatus.ok));
      processes.onRun = (List<String> arguments) =>
          Directory(p.join(arguments.last, AppUpdates.linuxBundleFolder)).createSync(recursive: true);
      final AppUpdater updater = updaterFor('linux', client);
      await updater.stage(AppRelease(version: Version(9, 0, 0), downloadUrl: Uri.parse(_downloadUrl)));

      expect(processes.ran.single.first, 'tar');
      expect(processes.started.single.first, 'sh');
      expect(processes.started.single, contains('42'));
      expect(processes.started.single.last, updater.executable);
    });

    test('stage fails on a build without the app, a failed unpack, or a bad download', () async {
      final AppRelease release = AppRelease(version: Version(9, 0, 0), downloadUrl: Uri.parse(_downloadUrl));
      final MockClient ok = MockClient((http.Request _) async => http.Response('archive', HttpStatus.ok));
      await expectLater(
        updaterFor('linux', ok).stage(release),
        throwsA(
          isA<AppUpdateException>().having((AppUpdateException e) => e.failure, 'f', AppUpdateFailure.invalidBuild),
        ),
      );

      processes.exitCode = 1;
      await expectLater(
        updaterFor('linux', ok).stage(release),
        throwsA(isA<AppUpdateException>().having((AppUpdateException e) => e.failure, 'f', AppUpdateFailure.unpack)),
      );

      final MockClient missing = MockClient((http.Request _) async => http.Response('', HttpStatus.notFound));
      await expectLater(updaterFor('linux', missing).stage(release), throwsA(isA<AppUpdateException>()));
      final MockClient offline = MockClient((http.Request _) async => throw const SocketException('offline'));
      await expectLater(updaterFor('linux', offline).stage(release), throwsA(isA<AppUpdateException>()));
      expect(processes.started, isEmpty);
    });

    test('stage refuses an install folder it cannot write', () async {
      final MockClient ok = MockClient((http.Request _) async => http.Response('', HttpStatus.ok));
      final AppUpdater updater = updaterFor('linux', ok, executable: p.join(install.path, 'missing', 'fpaint'));
      await expectLater(
        updater.stage(AppRelease(version: Version(9, 0, 0), downloadUrl: Uri.parse(_downloadUrl))),
        throwsA(
          isA<AppUpdateException>().having((AppUpdateException e) => e.failure, 'f', AppUpdateFailure.notWritable),
        ),
      );
    });

    test('macOS swaps the bundle around the executable', () async {
      final MockClient ok = MockClient((http.Request _) async => http.Response('', HttpStatus.ok));
      final String bundle = p.join(install.path, AppUpdates.macosAppBundle);
      final AppUpdater updater = updaterFor('macos', ok, executable: p.join(bundle, 'Contents', 'MacOS', 'fPaint'));
      expect(updater.installPath, bundle);
      expect(updater.writtenFolder, install.path);
      expect(updater.assetName, AppUpdates.macosAsset);
      expect(updater.appIn('u'), p.join('u', AppUpdates.macosAppBundle));
      await updater.unpack('a.zip', 'out');
      expect(processes.ran.single, <String>['ditto', '-x', '-k', 'a.zip', 'out']);
      await updater.startReplacer('new', 'staging');
      expect(processes.started.single.sublist(processes.started.single.length - 2), <String>['open', bundle]);
    });

    test('Windows unpacks and replaces with PowerShell', () async {
      final MockClient ok = MockClient((http.Request _) async => http.Response('', HttpStatus.ok));
      final AppUpdater updater = updaterFor('windows', ok);
      expect(updater.assetName, AppUpdates.windowsAsset);
      expect(updater.appIn('u'), 'u');
      await updater.unpack("it's.zip", 'out');
      expect(processes.ran.single.last, contains("'it''s.zip'"));
      await updater.startReplacer('new', 'staging');
      expect(processes.started.single.first, 'powershell');
      expect(processes.started.single.last, contains('Wait-Process -Id 42'));
    });
  });

  group('AppUpdateController', () {
    AppUpdater updaterReturning(String tag) => AppUpdater.forOperatingSystem(
      'linux',
      client: MockClient(
        (http.Request _) async => http.Response(jsonEncode(_releaseJson(tag, AppUpdates.linuxAsset)), HttpStatus.ok),
      ),
      executable: '/nowhere/fpaint',
      processId: 1,
    )!;

    test('finds only newer releases', () async {
      final AppUpdateController newer = AppUpdateController(
        updater: updaterReturning('v3.0.0'),
        runningVersion: Version(2, 0, 0),
      );
      await newer.check();
      expect(newer.available?.version, Version(3, 0, 0));

      final AppUpdateController same = AppUpdateController(
        updater: updaterReturning('v2.0.0'),
        runningVersion: Version(2, 0, 0),
      );
      await same.check();
      expect(same.available, isNull);
    });

    test('swallows check failures and is inert without an updater', () async {
      final AppUpdater failing = AppUpdater.forOperatingSystem(
        'linux',
        client: MockClient((http.Request _) async => http.Response('', HttpStatus.internalServerError)),
        executable: '/nowhere/fpaint',
        processId: 1,
      )!;
      final AppUpdateController controller = AppUpdateController(updater: failing, runningVersion: Version(1, 0, 0));
      await controller.check();
      expect(controller.available, isNull);

      final AppUpdateController inert = AppUpdateController(updater: null, runningVersion: Version(1, 0, 0));
      inert.start();
      await inert.check();
      await inert.install(confirmQuit: () async => true);
      expect(inert.available, isNull);
      inert.dispose();
    });

    test('install respects a declined quit and reports staging failures', () async {
      int quits = 0;
      final AppUpdateController controller = AppUpdateController(
        updater: updaterReturning('v3.0.0'),
        runningVersion: Version(2, 0, 0),
        quit: () => quits++,
      );
      await controller.check();
      await controller.install(confirmQuit: () async => false);
      expect(controller.installing, isFalse);

      // /nowhere is not writable, so staging fails and the app keeps running.
      await expectLater(controller.install(confirmQuit: () async => true), throwsA(isA<AppUpdateException>()));
      expect(controller.installing, isFalse);
      expect(quits, 0);
    });

    test('install stages the release then quits', () async {
      final Directory install = await Directory.systemTemp.createTemp('fpaint_update_ok_');
      addTearDown(() => install.delete(recursive: true));
      final _Processes processes = _Processes()
        ..onRun = (List<String> arguments) =>
            Directory(p.join(arguments.last, AppUpdates.linuxBundleFolder)).createSync(recursive: true);
      int quits = 0;
      final AppUpdateController controller = AppUpdateController(
        updater: AppUpdater.forOperatingSystem(
          'linux',
          client: MockClient(
            (http.Request request) async => request.url.host == AppUpdates.apiHost
                ? http.Response(jsonEncode(_releaseJson('v3.0.0', AppUpdates.linuxAsset)), HttpStatus.ok)
                : http.Response('archive', HttpStatus.ok),
          ),
          executable: p.join(install.path, 'fpaint'),
          processId: 1,
          run: processes.run,
          start: processes.start,
        ),
        runningVersion: Version(2, 0, 0),
        quit: () => quits++,
      );
      await controller.check();
      await controller.install(confirmQuit: () async => true);
      expect(quits, 1);
      expect(processes.started, hasLength(1));
    });

    test('start schedules checks once', () {
      final AppUpdateController controller = AppUpdateController(
        updater: updaterReturning('v3.0.0'),
        runningVersion: Version(2, 0, 0),
      );
      controller.start();
      controller.start();
      controller.dispose();
    });

    test('forThisBuild is inert in tests', () {
      expect(AppUpdateController.forThisBuild().updater, isNull);
    });

    test('exception describes itself', () {
      expect(const AppUpdateException(AppUpdateFailure.unpack, 'tar').toString(), 'unpack: tar');
    });
  });
}
