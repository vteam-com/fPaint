import 'package:fpaint/updates/app_update_constants.dart';
import 'package:pub_semver/pub_semver.dart';

/// An fPaint release published on GitHub: its version, and where the build of
/// the running operating system downloads from.
class AppRelease {
  /// Creates release [version], its build downloading from [downloadUrl].
  const AppRelease({required this.version, required this.downloadUrl});

  /// Where the build of the running operating system downloads from.
  final Uri downloadUrl;

  /// The release's version, read from its tag.
  final Version version;

  /// The release GitHub's API describes in [json], with the build named
  /// [assetName]; null when it has no such build or its tag names no version.
  static AppRelease? fromGitHub(Object? json, String assetName) {
    if (json case <String, Object?>{
      AppUpdates.jsonTagName: final String tag,
      AppUpdates.jsonAssets: final List<Object?> assets,
    }) {
      final Version? version = versionOfTag(tag);
      if (version == null) {
        return null;
      }
      for (final Object? asset in assets) {
        if (asset
            case <String, Object?>{
              AppUpdates.jsonAssetName: final String name,
              AppUpdates.jsonDownloadUrl: final String url,
            }
            when name == assetName) {
          return AppRelease(version: version, downloadUrl: Uri.parse(url));
        }
      }
    }
    return null;
  }

  /// The version release [tag] names, such as `v2.2.0`; null when it names none.
  static Version? versionOfTag(String tag) {
    if (!tag.startsWith(AppUpdates.tagPrefix)) {
      return null;
    }
    try {
      return Version.parse(tag.substring(AppUpdates.tagPrefix.length));
    } on FormatException {
      return null;
    }
  }
}
