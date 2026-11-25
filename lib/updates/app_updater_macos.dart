part of 'app_updater.dart';

/// The macOS [AppUpdater]: the build is the `.app` bundle, zipped with
/// `ditto`; the replacer swaps the whole bundle, so no file of the old version
/// breaks the new one's signature, and opens it.
class MacAppUpdater extends AppUpdater {
  /// Creates the updater of the bundle holding [executable].
  MacAppUpdater({
    required super.client,
    required super.executable,
    required super.processId,
    super.run,
    super.start,
  });

  static const String _ditto = 'ditto';
  static const String _open = 'open';

  /// Replacer step: moves the installed bundle (`$3`) into the staging folder
  /// (`$4`), then the new one (`$2`) into its place, restoring the old one
  /// when that fails.
  static const String _replaceScript = r'mv "$3" "$4/previous" && { mv "$2" "$3" || mv "$4/previous" "$3"; }';

  @override
  String get assetName => AppUpdates.macosAsset;

  /// The `.app` bundle holding [executable] in its `Contents/MacOS`.
  @override
  String get installPath {
    String path = executable;
    for (int level = 0; level < AppUpdates.macosBundleDepth; level++) {
      path = p.dirname(path);
    }
    return path;
  }

  /// The folder holding the bundle, where the replacer renames it.
  @override
  String get writtenFolder => p.dirname(installPath);

  @override
  String appIn(String unpacked) => p.join(unpacked, AppUpdates.macosAppBundle);

  /// Moves the installed bundle into the staging folder, which the script
  /// deletes, then the new one into its place; puts the old one back when
  /// that fails.
  @override
  Future<void> startReplacer(String newApp, String staging) => startShellReplacer(
    _replaceScript,
    newApp,
    staging,
    <String>[_open, installPath],
  );

  @override
  Future<void> unpack(String archive, String into) => runChecked(_ditto, <String>['-x', '-k', archive, into]);
}
