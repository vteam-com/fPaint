import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/models/version.dart';
import 'package:fpaint/updates/app_release.dart';
import 'package:fpaint/updates/app_update_constants.dart';
import 'package:fpaint/updates/app_updater.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:pub_semver/pub_semver.dart';

final Logger _log = Logger(logNameAppUpdate);

/// Asks whether the app may quit to update, saving or discarding work first.
typedef AppUpdateQuitConfirmation = Future<bool> Function();

/// Ends the app so the staged replacer can swap the new build in.
typedef AppQuit = void Function();

/// Watches GitHub for an fPaint release newer than the running one and
/// installs it on request.
///
/// [available] is the newer release, or null while up to date; [installing]
/// is true while the build downloads and unpacks. Checks run after
/// [AppUpdates.firstCheckDelay], then every [AppUpdates.checkInterval]; a
/// failed check waits for the next one rather than spending GitHub's rate
/// limit on retries.
class AppUpdateController extends ChangeNotifier {
  /// Creates a controller installing with [updater] over [runningVersion].
  AppUpdateController({
    required this.updater,
    required this.runningVersion,
    AppQuit? quit,
  }) : _quit = quit ?? _exitApp;

  /// The controller of this build: updating only release builds the Release
  /// workflow published, on desktop; otherwise one that never finds updates.
  factory AppUpdateController.forThisBuild() {
    final bool enabled = kReleaseMode && !kIsWeb && AppUpdates.channel == AppUpdates.githubChannel;
    return AppUpdateController(
      updater: enabled
          ? AppUpdater.forOperatingSystem(
              Platform.operatingSystem,
              client: http.Client(),
              executable: Platform.resolvedExecutable,
              processId: pid,
            )
          : null,
      runningVersion: Version.parse(packageVersion),
    );
  }

  /// The version of the running app.
  final Version runningVersion;

  /// Finds and installs releases; null where the app does not update itself.
  final AppUpdater? updater;

  final AppQuit _quit;
  AppRelease? _available;
  bool _installing = false;
  Timer? _timer;

  /// The newer release found by the last check, or null while up to date.
  AppRelease? get available => _available;

  /// Whether the newer release is downloading and unpacking.
  bool get installing => _installing;

  /// Starts the periodic checks; does nothing where updates are off.
  void start() {
    if (updater == null || _timer != null) {
      return;
    }
    _timer = Timer(AppUpdates.firstCheckDelay, () {
      unawaited(check());
      _timer = Timer.periodic(AppUpdates.checkInterval, (Timer _) => unawaited(check()));
    });
  }

  /// Asks GitHub for the latest release now; failures are logged, never thrown.
  Future<void> check() async {
    final AppUpdater? activeUpdater = updater;
    if (activeUpdater == null) {
      return;
    }
    try {
      final AppRelease? latest = await activeUpdater.latestRelease();
      final AppRelease? newer = latest != null && latest.version > runningVersion ? latest : null;
      if (newer?.version != _available?.version) {
        _available = newer;
        notifyListeners();
      }
    } on Exception catch (error) {
      _log.info('Update check failed: $error');
    }
  }

  /// Installs [available]: once [confirmQuit] agrees, downloads and stages the
  /// build, then quits for it to take the app's place and start.
  ///
  /// Does nothing without a newer release, while installing, or when
  /// [confirmQuit] declines. Throws when the build can't be staged, the app
  /// then running on unchanged.
  Future<void> install({required AppUpdateQuitConfirmation confirmQuit}) async {
    final AppRelease? release = _available;
    final AppUpdater? activeUpdater = updater;
    if (release == null || activeUpdater == null || _installing) {
      return;
    }
    if (!await confirmQuit()) {
      return;
    }
    _setInstalling(true);
    try {
      await activeUpdater.stage(release);
    } finally {
      _setInstalling(false);
    }
    _quit();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setInstalling(bool value) {
    _installing = value;
    notifyListeners();
  }

  static void _exitApp() => exit(0);
}
