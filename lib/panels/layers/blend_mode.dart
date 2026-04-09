import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';

const String _blendModeNormalFallback = 'Normal';

/// A comprehensive mapping of blend modes supported by the fPaint application.
///
/// Each blend mode includes its Flutter BlendMode equivalent and a human-readable
/// description explaining how the blend mode affects the compositing of layers.
///
/// Supported blend modes include:
/// - Normal: Standard overlay without blending
/// - Darken/Lighten: Color value comparisons
/// - Multiply/Screen: Mathematical color operations
/// - Overlay/Soft Light/Hard Light: Contrast adjustments
/// - Color operations: Hue, Saturation, Color, Luminosity adjustments
/// - Dodge/Burn: Contrast modifications
Map<String, Map<String, Object>> getSupportedBlendModes(final AppLocalizations l10n) => <String, Map<String, Object>>{
  'Normal': <String, Object>{
    'flutterBlendMode': BlendMode.srcOver,
    'description': l10n.blendModeNormalDescription,
  },
  'Darken': <String, Object>{
    'flutterBlendMode': BlendMode.darken,
    'description': l10n.blendModeDarkenDescription,
  },
  'Multiply': <String, Object>{
    'flutterBlendMode': BlendMode.multiply,
    'description': l10n.blendModeMultiplyDescription,
  },
  'Color Burn': <String, Object>{
    'flutterBlendMode': BlendMode.colorBurn,
    'description': l10n.blendModeColorBurnDescription,
  },
  'Lighten': <String, Object>{
    'flutterBlendMode': BlendMode.lighten,
    'description': l10n.blendModeLightenDescription,
  },
  'Screen': <String, Object>{
    'flutterBlendMode': BlendMode.screen,
    'description': l10n.blendModeScreenDescription,
  },
  'Color Dodge': <String, Object>{
    'flutterBlendMode': BlendMode.colorDodge,
    'description': l10n.blendModeColorDodgeDescription,
  },
  'Linear Dodge (Add)': <String, Object>{
    'flutterBlendMode': BlendMode.plus,
    'description': l10n.blendModeLinearDodgeDescription,
  },
  'Overlay': <String, Object>{
    'flutterBlendMode': BlendMode.overlay,
    'description': l10n.blendModeOverlayDescription,
  },
  'Soft Light': <String, Object>{
    'flutterBlendMode': BlendMode.softLight,
    'description': l10n.blendModeSoftLightDescription,
  },
  'Hard Light': <String, Object>{
    'flutterBlendMode': BlendMode.hardLight,
    'description': l10n.blendModeHardLightDescription,
  },
  'Hue': <String, Object>{
    'flutterBlendMode': BlendMode.hue,
    'description': l10n.blendModeHueDescription,
  },
  'Saturation': <String, Object>{
    'flutterBlendMode': BlendMode.saturation,
    'description': l10n.blendModeSaturationDescription,
  },
  'Color': <String, Object>{
    'flutterBlendMode': BlendMode.color,
    'description': l10n.blendModeColorDescription,
  },
  'Luminosity': <String, Object>{
    'flutterBlendMode': BlendMode.luminosity,
    'description': l10n.blendModeLuminosityDescription,
  },
};

/// Displays a popup menu for selecting blend modes.
///
/// Shows all supported blend modes in a contextual menu, allowing users to
/// select how layers should be composited together. Each menu item displays
/// the blend mode name and a description of its effect.
///
/// [context] The build context for displaying the menu.
/// [position] The screen position where the menu should appear.
/// [selectedBlendMode] The currently selected blend mode (for highlighting).
/// Returns the selected BlendMode, or BlendMode.srcOver if cancelled.
Future<BlendMode> showBlendModeMenu({
  required final BuildContext context,
  final Offset position = Offset.zero,
  final BlendMode? selectedBlendMode,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context)!;
  final Map<String, Map<String, Object>> blendModes = getSupportedBlendModes(l10n);
  return await showMenu<BlendMode>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx + 1,
          position.dy + 1,
        ),
        items: blendModes.entries.map((final MapEntry<String, Map<String, Object>> entry) {
          final BlendMode menuFlutterBlendMode = (entry.value['flutterBlendMode'] as BlendMode?) ?? BlendMode.srcOver;

          return PopupMenuItem<BlendMode>(
            value: menuFlutterBlendMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  selected: selectedBlendMode == menuFlutterBlendMode,
                  selectedColor: Colors.blue,
                  title: Text(entry.key),
                  subtitle: Text(
                    entry.value['description'] as String,
                    style: TextStyle(
                      fontSize: AppSpacing.lg,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ) ??
      BlendMode.srcOver;
}

/// Converts a BlendMode enum value to a human-readable string.
///
/// Special handling for BlendMode.srcOver which is displayed as "Normal"
/// for better user understanding. Other blend modes are capitalized
/// for proper display in UI elements.
///
/// [blendMode] The BlendMode to convert to text.
/// [l10n] Optional localizations for translated blend mode names.
/// Returns a capitalized string representation of the blend mode.
String blendModeToText(final BlendMode blendMode, [final AppLocalizations? l10n]) {
  if (blendMode == BlendMode.srcOver) {
    return l10n?.blendModeNormalLabel ?? _blendModeNormalFallback;
  }
  return blendMode.name[0].toUpperCase() + blendMode.name.substring(1);
}
