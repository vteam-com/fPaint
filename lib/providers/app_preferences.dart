import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/helpers/macos_bookmark_service.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:provider/provider.dart';

/// Manages the application's persistent settings using SharedPreferences.
class AppPreferences extends ChangeNotifier {
  AppPreferences() {
    unawaited(_loadInitialPreferences());
  }

  static final Logger _log = Logger(logNameAppPreferences);

  SharedPreferences? _prefs;
  Future<void>? _loadFuture;

  /// Retrieves the [AppPreferences] instance from the widget tree.
  static AppPreferences of(
    final BuildContext context, {
    final bool listen = false,
  }) => Provider.of<AppPreferences>(context, listen: listen);

  /// Indicates whether the preferences have been loaded.
  bool get isLoaded => _prefs != null;

  // Keys for preferences
  static const String keyBrushSize = 'keyBrushSize';
  static const String keyLastBrushColor = 'keyLastBrushColor';
  static const String keyLastFillColor = 'keyLastFillColor';
  static const String keySidePanelDistance = 'keySidePanelDistance';
  static const String keyUseApplePencil = 'keyUseApplePencil';
  static const String keyLanguageCode = 'keyLanguageCode';
  static const String keyRecoveryDraftSourceFilePath = 'keyRecoveryDraftSourceFilePath';
  static const String keyRecentFiles = 'keyRecentFiles';
  static const String keyRecentFileBookmarks = 'keyRecentFileBookmarks';

  /// Legacy separator used by the previous path+bookmark serialized format.
  static const String _legacyBookmarkSeparator = '\x00';

  // Default values
  double _sidePanelDistance = AppLayout.sidePanelTopDefault;
  double _brushSize = AppDefaults.brushSize;
  Color _brushColor = AppColors.black;
  Color _fillColor = AppColors.blue;
  bool _useApplePencil = true;
  String? _languageCode;
  List<String> _recentFiles = <String>[];

  /// macOS security-scoped bookmarks keyed by file path.
  Map<String, String> _recentFileBookmarks = <String, String>{};

  // Getters

  /// Gets the side panel distance.
  double get sidePanelDistance => _sidePanelDistance;

  /// Gets the brush size.
  double get brushSize => _brushSize;

  /// Gets the brush color.
  Color get brushColor => _brushColor;

  /// Gets the fill color.
  Color get fillColor => _fillColor;

  /// Gets whether to use Apple Pencil only.
  bool get useApplePencil => _useApplePencil;

  /// Gets the preferred app language code.
  ///
  /// Returns null to use system locale.
  String? get languageCode => _languageCode;

  /// Gets the preferred app locale.
  ///
  /// Returns null to use system locale.
  Locale? get preferredLocale => _languageCode == null ? null : Locale(_languageCode!);

  /// Gets the list of recently opened file paths (most recent first).
  List<String> get recentFiles => List<String>.unmodifiable(_recentFiles);

  /// Returns the macOS security-scoped bookmark string for [path], or null.
  String? getBookmark(final String path) => _recentFileBookmarks[path];

  /// Gets the SharedPreferences instance.
  Future<SharedPreferences> getPref() async {
    await _ensureLoaded();
    return _prefs!;
  }

  /// Sets the side panel distance.
  Future<void> setSidePanelDistance(
    final double value,
  ) async {
    _sidePanelDistance = value;
    await (await getPref()).setDouble(keySidePanelDistance, value);
  }

  /// Sets the brush size.
  Future<void> setBrushSize(final double size) async {
    _brushSize = size;
    await (await getPref()).setDouble(keyBrushSize, size);
  }

  /// Sets the brush color.
  Future<void> setBrushColor(final Color color) async {
    _brushColor = color;
    await (await getPref()).setInt(keyLastBrushColor, color.toARGB32());
  }

  /// Sets the fill color.
  Future<void> setFillColor(final Color color) async {
    _fillColor = color;
    await (await getPref()).setInt(keyLastFillColor, color.toARGB32());
  }

  /// Sets whether to use Apple Pencil only.
  Future<void> setUseApplePencil(
    final bool value,
  ) async {
    _useApplePencil = value;
    await (await getPref()).setBool(keyUseApplePencil, value);
    notifyListeners();
  }

  /// Sets the preferred app language code.
  ///
  /// Pass null to use the system locale.
  Future<void> setLanguageCode(final String? value) async {
    _languageCode = value;
    final SharedPreferences prefs = await getPref();
    if (value == null) {
      await prefs.remove(keyLanguageCode);
      notifyListeners();
      return;
    }
    await prefs.setString(keyLanguageCode, value);
    notifyListeners();
  }

  /// Persists the source file path associated with the recovery draft.
  Future<void> setRecoveryDraftSourceFilePath(final String? value) async {
    final SharedPreferences prefs = await getPref();
    if (value == null || value.isEmpty) {
      await prefs.remove(keyRecoveryDraftSourceFilePath);
      return;
    }

    await prefs.setString(keyRecoveryDraftSourceFilePath, value);
  }

  /// Returns the source file path associated with the recovery draft, if any.
  Future<String?> getRecoveryDraftSourceFilePath() async {
    return (await getPref()).getString(keyRecoveryDraftSourceFilePath);
  }

  /// Clears the stored recovery draft source file path.
  Future<void> clearRecoveryDraftSourceFilePath() async {
    await (await getPref()).remove(keyRecoveryDraftSourceFilePath);
  }

  /// Adds a file path to the recent files list.
  ///
  /// The path is moved to the front if already present. The list is capped at
  /// [AppLimits.maxRecentFiles]. On macOS a security-scoped bookmark is created
  /// and stored so the file can be re-opened across sessions.
  Future<void> addRecentFile(final String path) async {
    _recentFiles.remove(path);
    _recentFiles.insert(0, path);
    if (_recentFiles.length > AppLimits.maxRecentFiles) {
      _recentFiles = _recentFiles.sublist(0, AppLimits.maxRecentFiles);
    }
    _pruneRecentFileBookmarks();
    final SharedPreferences prefs = await getPref();
    await prefs.setStringList(keyRecentFiles, _recentFiles);
    // Store a security-scoped bookmark for macOS sandbox support.
    final String? bookmark = await MacOsBookmarkService.createBookmark(path);
    if (bookmark != null) {
      _recentFileBookmarks[path] = bookmark;
    }
    await _persistRecentFileBookmarks(prefs);
    notifyListeners();
  }

  /// Removes a file path from the recent files list.
  Future<void> removeRecentFile(final String path) async {
    _recentFiles.remove(path);
    _recentFileBookmarks.remove(path);
    final SharedPreferences prefs = await getPref();
    await prefs.setStringList(keyRecentFiles, _recentFiles);
    await _persistRecentFileBookmarks(prefs);
    notifyListeners();
  }

  /// Removes bookmarks for files that are no longer present in the MRU list.
  void _pruneRecentFileBookmarks() {
    _recentFileBookmarks.removeWhere(
      (final String path, final String _) => !_recentFiles.contains(path),
    );
  }

  /// Persists bookmark strings in the same order as [keyRecentFiles].
  Future<void> _persistRecentFileBookmarks(final SharedPreferences prefs) async {
    _pruneRecentFileBookmarks();
    if (_recentFiles.isEmpty) {
      await prefs.remove(keyRecentFileBookmarks);
      return;
    }

    final List<String> bookmarkEntries = _recentFiles
        .map((final String path) => _recentFileBookmarks[path] ?? '')
        .toList();
    await prefs.setStringList(keyRecentFileBookmarks, bookmarkEntries);
  }

  /// Ensures preferences are loaded once before any persisted value is read.
  ///
  /// Concurrent callers share the same in-flight load future so
  /// [SharedPreferences] initialization is not duplicated. Once loading
  /// completes, listeners are notified so widgets depending on persisted values
  /// can rebuild.
  Future<void> _ensureLoaded() async {
    if (_prefs != null) {
      return;
    }

    if (_loadFuture != null) {
      await _loadFuture;
      return;
    }

    _loadFuture = _loadPreferences();
    try {
      await _loadFuture;
      notifyListeners();
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> _loadInitialPreferences() async {
    try {
      await _ensureLoaded();
    } catch (error, stackTrace) {
      _log.severe('Failed to load app preferences.', error, stackTrace);
    }
  }

  /// Loads the preferences from SharedPreferences.
  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();

    _sidePanelDistance = _prefs!.getDouble(keySidePanelDistance) ?? AppLayout.sidePanelTopDefault;

    // Load brush size
    _brushSize = _prefs!.getDouble(keyBrushSize) ?? AppDefaults.brushSize;

    // Load last used color
    _brushColor = Color(_prefs!.getInt(keyLastBrushColor) ?? AppColors.black.toARGB32());

    _fillColor = Color(_prefs!.getInt(keyLastFillColor) ?? AppColors.blue.toARGB32());

    _useApplePencil = _prefs!.getBool(keyUseApplePencil) ?? AppDefaults.useApplePencil;

    _languageCode = _prefs!.getString(keyLanguageCode);

    _recentFiles = _prefs!.getStringList(keyRecentFiles) ?? <String>[];
    final List<String> storedBookmarkEntries = _prefs!.getStringList(keyRecentFileBookmarks) ?? <String>[];
    final _LoadedRecentFileBookmarks loadedRecentFileBookmarks = _loadRecentFileBookmarks(
      recentFiles: _recentFiles,
      storedEntries: storedBookmarkEntries,
    );
    _recentFileBookmarks = loadedRecentFileBookmarks.bookmarks;
    if (loadedRecentFileBookmarks.needsResave) {
      await _persistRecentFileBookmarks(_prefs!);
    }
  }

  /// Loads bookmark entries and repairs legacy macOS-pref storage formats.
  static _LoadedRecentFileBookmarks _loadRecentFileBookmarks({
    required final List<String> recentFiles,
    required final List<String> storedEntries,
  }) {
    final Map<String, String> bookmarks = <String, String>{};
    final int sharedEntryCount = storedEntries.length < recentFiles.length ? storedEntries.length : recentFiles.length;
    bool needsResave = storedEntries.length != recentFiles.length;

    for (int index = 0; index < sharedEntryCount; index++) {
      final _DecodedRecentFileBookmark decodedBookmark = _decodeStoredRecentFileBookmark(
        entry: storedEntries[index],
        path: recentFiles[index],
      );
      needsResave = needsResave || decodedBookmark.needsResave;
      final String? bookmark = decodedBookmark.bookmark;
      if (bookmark != null && bookmark.isNotEmpty) {
        bookmarks[recentFiles[index]] = bookmark;
      }
    }

    return _LoadedRecentFileBookmarks(
      bookmarks: bookmarks,
      needsResave: needsResave,
    );
  }

  /// Decodes a persisted bookmark entry for a single MRU path.
  static _DecodedRecentFileBookmark _decodeStoredRecentFileBookmark({
    required final String entry,
    required final String path,
  }) {
    if (entry.isEmpty) {
      return const _DecodedRecentFileBookmark(
        bookmark: null,
        needsResave: false,
      );
    }

    if (entry == path) {
      return const _DecodedRecentFileBookmark(
        bookmark: null,
        needsResave: true,
      );
    }

    final int separatorIndex = entry.indexOf(_legacyBookmarkSeparator);
    if (separatorIndex >= 0) {
      final String bookmark = entry.substring(separatorIndex + 1);
      return _DecodedRecentFileBookmark(
        bookmark: bookmark.isEmpty ? null : bookmark,
        needsResave: true,
      );
    }

    if (entry.startsWith(path)) {
      final String bookmark = entry.substring(path.length);
      return _DecodedRecentFileBookmark(
        bookmark: bookmark.isEmpty ? null : bookmark,
        needsResave: true,
      );
    }

    return _DecodedRecentFileBookmark(
      bookmark: entry,
      needsResave: false,
    );
  }
}

class _LoadedRecentFileBookmarks {
  const _LoadedRecentFileBookmarks({
    required this.bookmarks,
    required this.needsResave,
  });

  final Map<String, String> bookmarks;
  final bool needsResave;
}

class _DecodedRecentFileBookmark {
  const _DecodedRecentFileBookmark({
    required this.bookmark,
    required this.needsResave,
  });

  final String? bookmark;
  final bool needsResave;
}
