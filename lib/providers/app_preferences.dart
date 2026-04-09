import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:provider/provider.dart';

/// Manages the application's persistent settings using SharedPreferences.
class AppPreferences {
  SharedPreferences? _prefs;

  /// Indicates whether the preferences have been loaded.
  bool get isLoaded => _prefs != null;

  // Keys for preferences
  static const String keyBrushSize = 'keyBrushSize';
  static const String keyLastBrushColor = 'keyLastBrushColor';
  static const String keyLastFillColor = 'keyLastFillColor';
  static const String keySidePanelDistance = 'keySidePanelDistance';
  static const String keyUseApplePencil = 'keyUseApplePencil';
  static const String keyLanguageCode = 'keyLanguageCode';

  // Default values
  double _sidePanelDistance = AppLayout.sidePanelTopDefault;
  double _brushSize = AppDefaults.brushSize;
  Color _brushColor = Colors.black;
  Color _fillColor = Colors.blue;
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
    if (_prefs == null) {
      await _loadPreferences();
    }
    return _prefs!;
  }

  /// Sets the side panel distance.
  Future<void> setSidePanelDistance(
    final double value,
  ) async {
    _sidePanelDistance = value;
    (await getPref()).setDouble(keySidePanelDistance, value);
  }

  /// Sets the brush size.
  Future<void> setBrushSize(final double size) async {
    _brushSize = size;
    (await getPref()).setDouble(keyBrushSize, size);
  }

  /// Sets the brush color.
  Future<void> setBrushColor(final Color color) async {
    _brushColor = color;
    (await getPref()).setInt(keyLastBrushColor, color.toARGB32());
  }

  /// Sets the fill color.
  Future<void> setFillColor(final Color color) async {
    _fillColor = color;
    (await getPref()).setInt(keyLastFillColor, color.toARGB32());
  }

  /// Sets whether to use Apple Pencil only.
  Future<void> setUseApplePencil(
    final bool value,
  ) async {
    _useApplePencil = value;
    (await getPref()).setBool(keyUseApplePencil, value);
  }

  /// Sets the preferred app language code.
  ///
  /// Pass null to use the system locale.
  Future<void> setLanguageCode(final String? value) async {
    _languageCode = value;
    final SharedPreferences prefs = await getPref();
    if (value == null) {
      await prefs.remove(keyLanguageCode);
      return;
    }
    await prefs.setString(keyLanguageCode, value);
  }

  /// Loads the preferences from SharedPreferences.
  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();

    _sidePanelDistance = _prefs!.getDouble(keySidePanelDistance) ?? AppLayout.sidePanelTopDefault;

    // Load brush size
    _brushSize = _prefs!.getDouble(keyBrushSize) ?? AppDefaults.brushSize;

    // Load last used color
    _brushColor = Color(_prefs!.getInt(keyLastBrushColor) ?? Colors.black.toARGB32());

    _fillColor = Color(_prefs!.getInt(keyLastFillColor) ?? Colors.blue.toARGB32());

    _useApplePencil = _prefs!.getBool(keyUseApplePencil) ?? AppDefaults.useApplePencil;

    _languageCode = _prefs!.getString(keyLanguageCode);
  }
}
