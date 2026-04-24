import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/log_helper.dart';
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

  // Default values
  double _sidePanelDistance = AppLayout.sidePanelTopDefault;
  double _brushSize = AppDefaults.brushSize;
  Color _brushColor = AppPalette.black;
  Color _fillColor = AppPalette.blue;
  bool _useApplePencil = true;
  String? _languageCode;

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
    _brushColor = Color(_prefs!.getInt(keyLastBrushColor) ?? AppPalette.black.toARGB32());

    _fillColor = Color(_prefs!.getInt(keyLastFillColor) ?? AppPalette.blue.toARGB32());

    _useApplePencil = _prefs!.getBool(keyUseApplePencil) ?? AppDefaults.useApplePencil;

    _languageCode = _prefs!.getString(keyLanguageCode);
  }
}
