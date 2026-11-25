/// Constants of the desktop self-updater: where releases are published, how
/// the Release workflow names each build, and how an update is staged.
///
/// Kept in step with `.github/workflows/release.yml`, which builds and names
/// the assets, and `tool/release.sh`, which tags them.
class AppUpdates {
  /// The `--dart-define` the Release workflow sets to turn self-updating on.
  static const String channelDefine = 'FPAINT_UPDATE_CHANNEL';

  /// The [channelDefine] value of builds published as GitHub Releases.
  static const String githubChannel = 'github';

  /// The update channel this build was made for; empty for local, store and
  /// web builds, which never update themselves.
  static const String channel = String.fromEnvironment(channelDefine);

  /// Host of GitHub's REST API.
  static const String apiHost = 'api.github.com';

  /// The GitHub repository publishing fPaint's releases.
  static const String repository = 'vteam-com/fPaint';

  /// API path describing the latest published release.
  static const String latestReleasePath = '/repos/$repository/releases/latest';

  /// What starts a release tag, before its version: `v2.2.0`.
  static const String tagPrefix = 'v';

  /// JSON key of a release's tag.
  static const String jsonTagName = 'tag_name';

  /// JSON key of a release's files.
  static const String jsonAssets = 'assets';

  /// JSON key of a release file's name.
  static const String jsonAssetName = 'name';

  /// JSON key of a release file's download URL.
  static const String jsonDownloadUrl = 'browser_download_url';

  /// Where the latest release's files download from, by name.
  static const String latestDownloadBase = 'https://github.com/$repository/releases/latest/download/';

  /// The macOS build: the `.app` bundle, zipped with `ditto`.
  static const String macosAsset = 'fPaint-macos.zip';

  /// The Windows build: the runner's Release folder, zipped.
  static const String windowsAsset = 'fPaint-windows.zip';

  /// The Linux build: the `bundle` folder, in a gzipped tarball.
  static const String linuxAsset = 'fPaint-linux.tar.gz';

  /// Download link of the latest macOS build.
  static const String macosDownloadUrl = '$latestDownloadBase$macosAsset';

  /// Download link of the latest Windows build.
  static const String windowsDownloadUrl = '$latestDownloadBase$windowsAsset';

  /// Download link of the latest Linux build.
  static const String linuxDownloadUrl = '$latestDownloadBase$linuxAsset';

  /// The macOS app bundle inside [macosAsset].
  static const String macosAppBundle = 'fPaint.app';

  /// The folder inside [linuxAsset] holding the app.
  static const String linuxBundleFolder = 'bundle';

  /// Folder levels from the macOS executable up to its bundle:
  /// `fPaint.app/Contents/MacOS/fPaint`.
  static const int macosBundleDepth = 3;

  /// Prefix of the temporary folder a build is downloaded into.
  static const String stagingPrefix = 'fpaint_update_';

  /// Folder of the staging folder the build unpacks into.
  static const String unpackedFolder = 'unpacked';

  /// The file written then deleted to learn whether the install folder is
  /// writable.
  static const String writeProbe = '.fpaint_update_probe';

  /// Delay after launch before the first check, so startup stays quick.
  static const Duration firstCheckDelay = Duration(seconds: 10);

  /// Time between two checks while the app stays open.
  static const Duration checkInterval = Duration(hours: 6);
}
