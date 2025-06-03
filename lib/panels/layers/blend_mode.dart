import 'package:flutter/material.dart';

final Map<String, Map<String, Object>> supportedBlendModes = <String, Map<String, Object>>{
  'Normal': <String, Object>{
    'flutterBlendMode': BlendMode.srcOver,
    'description': 'Places the source image over the destination without blending.',
  },
  'Darken': <String, Object>{
    'flutterBlendMode': BlendMode.darken,
    'description': 'Keeps the darker color of the source and destination pixels.',
  },
  'Multiply': <String, Object>{
    'flutterBlendMode': BlendMode.multiply,
    'description': 'Multiplies the source and destination colors, resulting in a darker output.',
  },
  'Color Burn': <String, Object>{
    'flutterBlendMode': BlendMode.colorBurn,
    'description': 'Darkens the destination by increasing contrast based on the source color.',
  },
  'Lighten': <String, Object>{
    'flutterBlendMode': BlendMode.lighten,
    'description': 'Keeps the lighter color of the source and destination pixels.',
  },
  'Screen': <String, Object>{
    'flutterBlendMode': BlendMode.screen,
    'description': 'Multiplies the inverses of the source and destination, resulting in a lighter output.',
  },
  'Color Dodge': <String, Object>{
    'flutterBlendMode': BlendMode.colorDodge,
    'description': 'Brightens the destination by reducing contrast based on the source color.',
  },
  'Linear Dodge (Add)': <String, Object>{
    'flutterBlendMode': BlendMode.plus,
    'description': 'Adds the source and destination colors, clamping at white.',
  },
  'Overlay': <String, Object>{
    'flutterBlendMode': BlendMode.overlay,
    'description': 'Combines multiply and screen modes: darkens dark areas, and lightens light areas.',
  },
  'Soft Light': <String, Object>{
    'flutterBlendMode': BlendMode.softLight,
    'description': 'Softens the contrast by darkening or lightening the destination depending on the source.',
  },
  'Hard Light': <String, Object>{
    'flutterBlendMode': BlendMode.hardLight,
    'description': 'Applies multiply or screen based on the source color’s intensity, creating a strong contrast.',
  },
  'Hue': <String, Object>{
    'flutterBlendMode': BlendMode.hue,
    'description': 'Uses the source’s hue and the destination’s saturation and luminance.',
  },
  'Saturation': <String, Object>{
    'flutterBlendMode': BlendMode.saturation,
    'description': 'Uses the source’s saturation and the destination’s hue and luminance.',
  },
  'Color': <String, Object>{
    'flutterBlendMode': BlendMode.color,
    'description': 'Uses the source’s hue and saturation, but keeps the destination’s luminance.',
  },
  'Luminosity': <String, Object>{
    'flutterBlendMode': BlendMode.luminosity,
    'description': 'Uses the source’s luminance and the destination’s hue and saturation.',
  },
  // TODO
  //   'Linear Burn': {
  //   'flutterBlendMode': null,
  //   'description': 'Subtracts the source from the destination, clamping at black.',
  // },
  // 'Glow': {
  //   'flutterBlendMode': null,
  //   'description': 'Simulates an outer glow effect by brightening colors and adding a soft blur.',
  // },
  // 'Soft Glow': {
  //   'flutterBlendMode': null,
  //   'description': 'Combines a subtle glow effect with color adjustments for a softened, luminous look.',
  // },
};

Future<BlendMode> showBlendModeMenu({
  required final BuildContext context,
  final Offset position = Offset.zero,
  final BlendMode? selectedBlendMode,
}) async {
  return await showMenu<BlendMode>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx + 1,
          position.dy + 1,
        ),
        items: supportedBlendModes.entries.map((final MapEntry<String, Map<String, Object>> entry) {
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
                      fontSize: 12,
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

String blendModeToText(final BlendMode blendMode) {
  if (blendMode == BlendMode.srcOver) {
    return 'Normal';
  }
  return blendMode.name[0].toUpperCase() + blendMode.name.substring(1);
}
