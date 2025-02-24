import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:provider/provider.dart';

class AppPreferences {
  SharedPreferences? _prefs;

  bool get isLoaded => _prefs != null;

  // Keys for preferences
  static const String themeModeKey = 'theme_mode';
  static const String brushSizeKey = 'brush_size';
  static const String lastColorKey = 'last_color';
  static const String keySidePanelDistance = 'keySidePanelDistance';

  // Default values
  ThemeMode _themeMode = ThemeMode.system;
  double _brushSize = 5.0;
  double _sidePanelDistance = 200;
  Color _lastColor = Colors.black;

  // Getters
  ThemeMode get themeMode => _themeMode;
  double get brushSize => _brushSize;
  double get sidePanelDistance => _sidePanelDistance;
  Color get lastColor => _lastColor;

  Future<SharedPreferences> getPref() async {
    if (_prefs == null) {
      await _loadPreferences();
    }
    return _prefs!;
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();

    // Load theme mode
    final int themeModeIndex = _prefs!.getInt(themeModeKey) ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];

    // Load brush size
    _brushSize = _prefs!.getDouble(brushSizeKey) ?? 5.0;

    // Load last used color
    // ignore: deprecated_member_use
    _lastColor = Color(_prefs!.getInt(lastColorKey) ?? Colors.black.value);

    _sidePanelDistance = _prefs!.getDouble(keySidePanelDistance) ?? 200.0;
  }

  Future<void> setThemeMode(final ThemeMode mode) async {
    _themeMode = mode;
    (await getPref()).setInt(themeModeKey, mode.index);
  }

  Future<void> setBrushSize(final double size) async {
    _brushSize = size;
    (await getPref()).setDouble(brushSizeKey, size);
  }

  Future<void> setLastColor(final Color color) async {
    _lastColor = color;
    // ignore: deprecated_member_use
    (await getPref()).setInt(lastColorKey, color.value);
  }

  Future<void> setSidePanelDistance(
    final double value,
  ) async {
    _sidePanelDistance = value;
    (await getPref()).setDouble(keySidePanelDistance, value);
  }
}
