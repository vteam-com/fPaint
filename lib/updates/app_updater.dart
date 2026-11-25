import 'dart:convert';
import 'dart:io';

import 'package:fpaint/updates/app_release.dart';
import 'package:fpaint/updates/app_update_constants.dart';
import 'package:fpaint/updates/app_update_exception.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

part 'app_updater_linux.dart';
part 'app_updater_macos.dart';
part 'app_updater_windows.dart';

/// Runs a command to completion, as [Process.run] does.
typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Starts a command, as [Process.start] does.
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  ProcessStartMode mode,
});

/// The shell running the macOS and Linux replacer scripts.
const String _shell = 'sh';

/// The `sh -c` option running a script given inline.
const String _shellInline = '-c';

/// Keeps fPaint up to date: finds its latest release on GitHub, downloads the
/// build of the running operating system, and puts it in the app's place.
///
/// fPaint can't replace itself while it runs: [stage] starts a detached
/// replacer that waits for fPaint to quit, swaps the new build in, and starts
/// it. One subclass per operating system, as the Release workflow packages
/// each build its own way.
abstract class AppUpdater {
  /// Creates the updater of the app run from [executable] as [processId].
  AppUpdater({
    required this.client,
    required this.executable,
    required this.processId,
    ProcessRunner? run,
    ProcessStarter? start,
  }) : run = run ?? Process.run,
       start = start ?? Process.start;

  /// The updater of [operatingSystem] (as [Platform.operatingSystem] names it),
  /// or null where fPaint does not update itself.
  static AppUpdater? forOperatingSystem(
    String operatingSystem, {
    required http.Client client,
    required String executable,
    required int processId,
    ProcessRunner? run,
    ProcessStarter? start,
  }) {
    return switch (operatingSystem) {
      _macos => MacAppUpdater(client: client, executable: executable, processId: processId, run: run, start: start),
      _windows => WindowsAppUpdater(
        client: client,
        executable: executable,
        processId: processId,
        run: run,
        start: start,
      ),
      _linux => LinuxAppUpdater(client: client, executable: executable, processId: processId, run: run, start: start),
      _ => null,
    };
  }

  static const String _linux = 'linux';
  static const String _macos = 'macos';
  static const String _windows = 'windows';

  /// Where GitHub's API describes the latest release.
  static final Uri latestReleaseUrl = Uri.https(AppUpdates.apiHost, AppUpdates.latestReleasePath);

  /// Downloads the release description and its build.
  final http.Client client;

  /// The running app's executable, as [Platform.resolvedExecutable] names it.
  final String executable;

  /// The running app's process id; the replacer waits for it to end.
  final int processId;

  /// Runs the commands unpacking the build.
  final ProcessRunner run;

  /// Starts the detached replacer.
  final ProcessStarter start;

  /// This operating system's build among a release's files.
  String get assetName;

  /// The installed app an update replaces.
  String get installPath;

  /// The folder the replacer writes in: [installPath] itself, unless the
  /// replacer swaps it whole.
  String get writtenFolder => installPath;

  /// The new app inside [unpacked], the folder its build unpacked into.
  String appIn(String unpacked);

  /// Starts the replacer, detached: once fPaint has quit it puts [newApp] in
  /// place of [installPath], deletes [staging], and starts the new app.
  Future<void> startReplacer(String newApp, String staging);

  /// Unpacks the build [archive] into the folder [into].
  Future<void> unpack(String archive, String into);

  /// The latest release, or null when it has no build of this operating system.
  ///
  /// Throws [AppUpdateException] when GitHub can't be reached or answers with
  /// an error.
  Future<AppRelease?> latestRelease() async {
    final http.Response response;
    try {
      response = await client.get(latestReleaseUrl);
    } on Exception catch (error) {
      throw AppUpdateException(AppUpdateFailure.network, '$latestReleaseUrl $error');
    }
    _checkAnswered(response, latestReleaseUrl);
    return AppRelease.fromGitHub(jsonDecode(response.body), assetName);
  }

  /// Downloads [release]'s build, unpacks it, then starts the replacer; the
  /// app must quit for the replacer to go on.
  ///
  /// Throws [AppUpdateException], leaving nothing behind, when fPaint can't
  /// write in [writtenFolder] or a step fails.
  Future<void> stage(AppRelease release) async {
    await _checkWritable();
    final Directory staging = await Directory.systemTemp.createTemp(AppUpdates.stagingPrefix);
    try {
      final String archive = p.join(staging.path, assetName);
      await _download(release.downloadUrl, archive);
      final String unpacked = p.join(staging.path, AppUpdates.unpackedFolder);
      await Directory(unpacked).create();
      await unpack(archive, unpacked);
      final String newApp = appIn(unpacked);
      if (!await FileSystemEntity.isDirectory(newApp)) {
        throw AppUpdateException(AppUpdateFailure.invalidBuild, newApp);
      }
      await startReplacer(newApp, staging.path);
    } catch (_) {
      await staging.delete(recursive: true);
      rethrow;
    }
  }

  /// Runs [executable] with [arguments], throwing when it fails.
  Future<void> runChecked(String executable, List<String> arguments) async {
    final ProcessResult result = await run(executable, arguments);
    if (result.exitCode != 0) {
      throw AppUpdateException(AppUpdateFailure.unpack, '$executable ${result.stderr}'.trim());
    }
  }

  /// Starts the macOS/Linux replacer, a shell script: once fPaint has quit,
  /// [replace] puts the new app (`$2`) in place of the installed one (`$3`);
  /// the script then deletes the staging folder (`$4`) and runs [relaunch].
  Future<void> startShellReplacer(
    String replace,
    String newApp,
    String staging,
    List<String> relaunch,
  ) async {
    final String script = <String>[
      r'while kill -0 "$1" 2>/dev/null; do sleep 1; done',
      replace,
      r'rm -rf "$4"',
      'shift 4',
      r'exec "$@"',
    ].join('\n');
    await start(
      _shell,
      <String>[_shellInline, script, _shell, '$processId', newApp, installPath, staging, ...relaunch],
      mode: ProcessStartMode.detached,
    );
  }

  /// Throws when fPaint can't write in [writtenFolder].
  Future<void> _checkWritable() async {
    final File probe = File(p.join(writtenFolder, AppUpdates.writeProbe));
    try {
      await probe.writeAsString('');
      await probe.delete();
    } on FileSystemException {
      throw AppUpdateException(AppUpdateFailure.notWritable, writtenFolder);
    }
  }

  /// Downloads [url] into the file [path].
  Future<void> _download(Uri url, String path) async {
    final http.StreamedResponse response;
    try {
      response = await client.send(http.Request(_httpGet, url));
    } on Exception catch (error) {
      throw AppUpdateException(AppUpdateFailure.network, '$url $error');
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.stream.drain<void>();
    }
    _checkAnswered(response, url);
    await response.stream.pipe(File(path).openWrite());
  }

  static const String _httpGet = 'GET';

  /// Throws when [response], from [url], is no success.
  static void _checkAnswered(http.BaseResponse response, Uri url) {
    if (response.statusCode != HttpStatus.ok) {
      throw AppUpdateException(AppUpdateFailure.network, '$url ${response.statusCode}');
    }
  }
}
