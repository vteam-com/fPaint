part of 'app_updater.dart';

/// The Linux [AppUpdater]: the build is the `bundle` folder in a `tar.gz`; the
/// replacer copies its files over the installed ones, leaving any other file
/// of that folder alone, and starts [executable].
class LinuxAppUpdater extends AppUpdater {
  /// Creates the updater of the bundle holding [executable].
  LinuxAppUpdater({
    required super.client,
    required super.executable,
    required super.processId,
    super.run,
    super.start,
  });

  static const String _tar = 'tar';

  /// Replacer step: copies the new bundle (`$2`) over the installed one (`$3`).
  static const String _replaceScript = r'cp -Rf "$2/." "$3/"';

  @override
  String get assetName => AppUpdates.linuxAsset;

  /// The bundle folder holding [executable].
  @override
  String get installPath => p.dirname(executable);

  @override
  String appIn(String unpacked) => p.join(unpacked, AppUpdates.linuxBundleFolder);

  @override
  Future<void> startReplacer(String newApp, String staging) =>
      startShellReplacer(_replaceScript, newApp, staging, <String>[executable]);

  @override
  Future<void> unpack(String archive, String into) => runChecked(_tar, <String>['-xzf', archive, '-C', into]);
}
