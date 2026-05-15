import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String _channelName = 'com.vteam.fpaint/file';
const String _createBookmark = 'createBookmark';
const String _resolveBookmark = 'resolveBookmark';
const String _releaseBookmark = 'releaseBookmark';

const MethodChannel _channel = MethodChannel(_channelName);

/// Provides macOS security-scoped bookmark support for sandboxed file access.
///
/// On macOS, a sandboxed app must obtain a security-scoped bookmark when first
/// accessing a user-selected file, then resolve that bookmark on subsequent
/// accesses. This service wraps the native bookmark APIs via a method channel.
///
/// On non-macOS platforms this service is a no-op: [createBookmark] returns
/// `null` and [withResolvedBookmark] calls the callback directly.
class MacOsBookmarkService {
  const MacOsBookmarkService._();

  /// Creates a security-scoped bookmark for [path] and returns it as a
  /// base-64 string, or `null` if the platform is not macOS or the call fails.
  static Future<String?> createBookmark(final String path) async {
    if (!_isMacOS) {
      return null;
    }
    try {
      final Object? result = await _channel.invokeMethod<String>(_createBookmark, path);
      return result as String?;
    } catch (_) {
      return null;
    }
  }

  /// Resolves [bookmarkBase64] to grant sandbox access, calls [action] with
  /// the resolved path, then releases the resource.
  ///
  /// If [bookmarkBase64] is `null` or the platform is not macOS, [action] is
  /// called with [fallbackPath] directly.
  static Future<T> withResolvedBookmark<T>({
    required final String? bookmarkBase64,
    required final String fallbackPath,
    required final Future<T> Function(String) action,
  }) async {
    if (!_isMacOS || bookmarkBase64 == null) {
      return action(fallbackPath);
    }
    String? resolvedPath;
    try {
      resolvedPath = await _channel.invokeMethod<String>(_resolveBookmark, bookmarkBase64);
    } catch (_) {
      // Fall back to direct path access if bookmark resolution fails.
    }
    final String pathToUse = resolvedPath ?? fallbackPath;
    try {
      return await action(pathToUse);
    } finally {
      if (resolvedPath != null) {
        try {
          await _channel.invokeMethod<void>(_releaseBookmark, resolvedPath);
        } catch (_) {
          // Best-effort release.
        }
      }
    }
  }

  static bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS && !kIsWeb;
}
