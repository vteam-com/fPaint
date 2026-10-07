import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(logNameSecurityScopedFile);

const String _channelName = 'com.vteam.fpaint/file';
const String _createBookmark = 'createBookmark';
const String _getOpenedFileBookmark = 'getOpenedFileBookmark';
const String _pickDocumentInPlace = 'pickDocumentInPlace';
const String _replaceFileWithBackup = 'replaceFileWithBackup';
const String _resolveBookmark = 'resolveBookmark';
const String _releaseBookmark = 'releaseBookmark';
const String _writeFileCoordinated = 'writeFileCoordinated';
const String _argBackupFileName = 'backupFileName';
const String _argBookmark = 'bookmark';
const String _argPath = 'path';
const String _argReplacementPath = 'replacementPath';
const String _argSourcePath = 'sourcePath';
const String _argTargetPath = 'targetPath';

const MethodChannel _channel = MethodChannel(_channelName);

/// A document the user picked in place on iOS, with the bookmark that grants
/// the app access to it outside its sandbox.
typedef InPlaceDocument = ({String path, String bookmark});

/// Provides security-scoped file access for user-selected files on Apple
/// platforms.
///
/// On macOS, a sandboxed app must obtain a security-scoped bookmark when first
/// accessing a user-selected file, then resolve that bookmark on subsequent
/// accesses. On iOS, documents picked from the Files app (iCloud Drive,
/// Synology Drive and other File Provider locations) are opened in place: the
/// picker returns a bookmark, and saves are written back through a coordinated
/// write so the provider syncs them. This service wraps the native APIs via a
/// method channel.
///
/// On other platforms this service is a no-op: [createBookmark] returns
/// `null` and [withResolvedBookmark] calls the callback directly.
class SecurityScopedFileService {
  const SecurityScopedFileService._();

  /// Whether the current platform can use the native replace-with-backup flow.
  static bool get supportsReplaceFileWithBackup => _isMacOS;

  /// Whether documents are opened in place through the native picker, and
  /// saved back to them through a coordinated write.
  static bool get supportsInPlaceDocuments => _isIOS;

  /// Creates a security-scoped bookmark for [path] and returns it as a
  /// base-64 string, or `null` if the platform is not macOS or the call fails.
  ///
  /// iOS bookmarks come from [pickDocumentInPlace] instead: a bookmark can
  /// only be created while the picker's access grant is active.
  static Future<String?> createBookmark(String path) async {
    if (!_isMacOS) {
      return null;
    }
    try {
      final Object? result = await _channel.invokeMethod<String>(_createBookmark, path);
      return result as String?;
    } catch (e, stackTrace) {
      _log.warning('Failed to create security-scoped bookmark', e, stackTrace);
      return null;
    }
  }

  /// Presents the iOS document picker in open-in-place mode.
  ///
  /// Returns the picked document's path and bookmark, or `null` when the user
  /// cancels or the platform does not support in-place documents.
  static Future<InPlaceDocument?> pickDocumentInPlace() async {
    if (!supportsInPlaceDocuments) {
      return null;
    }
    final Map<Object?, Object?>? result = await _channel.invokeMethod<Map<Object?, Object?>>(_pickDocumentInPlace);
    final Object? path = result?[_argPath];
    final Object? bookmark = result?[_argBookmark];
    if (path is! String || bookmark is! String) {
      return null;
    }
    return (path: path, bookmark: bookmark);
  }

  /// Returns the bookmark of a document the system asked the app to open in
  /// place (iOS "Open in fPaint" from the Files app), or `null` when [path]
  /// needs none or the platform does not support in-place documents.
  static Future<String?> openedFileBookmark(String path) async {
    if (!supportsInPlaceDocuments) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>(_getOpenedFileBookmark, path);
    } catch (e, stackTrace) {
      _log.warning('Failed to read the opened document bookmark', e, stackTrace);
      return null;
    }
  }

  /// Copies [sourcePath] over [targetPath] inside an iOS file-coordinated
  /// write, so the File Provider that owns [targetPath] uploads the change.
  ///
  /// The caller must hold access to [targetPath] (see [withResolvedBookmark]).
  static Future<void> writeFileCoordinated({
    required String targetPath,
    required String sourcePath,
  }) async {
    await _channel.invokeMethod<void>(_writeFileCoordinated, <String, String>{
      _argSourcePath: sourcePath,
      _argTargetPath: targetPath,
    });
  }

  /// Replaces [targetPath] with [replacementPath] while asking macOS to keep
  /// the previous file as [backupFileName] beside it.
  static Future<bool> replaceFileWithBackup({
    required String targetPath,
    required String replacementPath,
    required String backupFileName,
  }) async {
    if (!_isMacOS) {
      return false;
    }
    try {
      await _channel.invokeMethod<void>(_replaceFileWithBackup, <String, String>{
        _argBackupFileName: backupFileName,
        _argReplacementPath: replacementPath,
        _argTargetPath: targetPath,
      });
      return true;
    } catch (e, stackTrace) {
      _log.warning('Failed to replace file with backup', e, stackTrace);
      return false;
    }
  }

  /// Resolves [bookmarkBase64] to grant sandbox access, calls [action] with
  /// the resolved path, then releases the resource.
  ///
  /// If [bookmarkBase64] is `null` or the platform has no bookmarks, [action]
  /// is called with [fallbackPath] directly.
  static Future<T> withResolvedBookmark<T>({
    required String? bookmarkBase64,
    required String fallbackPath,
    required Future<T> Function(String) action,
  }) async {
    if (!_supportsBookmarks || bookmarkBase64 == null) {
      return action(fallbackPath);
    }
    String? resolvedPath;
    try {
      resolvedPath = await _channel.invokeMethod<String>(_resolveBookmark, bookmarkBase64);
    } catch (e, stackTrace) {
      // Fall back to direct path access if bookmark resolution fails.
      _log.warning('Failed to resolve security-scoped bookmark; using direct path', e, stackTrace);
    }
    final String pathToUse = resolvedPath ?? fallbackPath;
    try {
      return await action(pathToUse);
    } finally {
      if (resolvedPath != null) {
        try {
          await _channel.invokeMethod<void>(_releaseBookmark, resolvedPath);
        } catch (e, stackTrace) {
          // Best-effort release.
          _log.warning('Failed to release security-scoped bookmark', e, stackTrace);
        }
      }
    }
  }

  static bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS && !kIsWeb;

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb;

  static bool get _supportsBookmarks => _isMacOS || _isIOS;
}
