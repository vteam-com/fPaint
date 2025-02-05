import 'package:flutter/material.dart';

final supportedBlendModes = {
  'Normal': {
    'flutterBlendMode': BlendMode.srcOver,
    'description':
        'Places the source image over the destination without blending.',
  },
  'Darken': {
    'flutterBlendMode': BlendMode.darken,
    'description':
        'Keeps the darker color of the source and destination pixels.',
  },
  'Multiply': {
    'flutterBlendMode': BlendMode.multiply,
    'description':
        'Multiplies the source and destination colors, resulting in a darker output.',
  },
  'Color Burn': {
    'flutterBlendMode': BlendMode.colorBurn,
    'description':
        'Darkens the destination by increasing contrast based on the source color.',
  },
  'Lighten': {
    'flutterBlendMode': BlendMode.lighten,
    'description':
        'Keeps the lighter color of the source and destination pixels.',
  },
  'Screen': {
    'flutterBlendMode': BlendMode.screen,
    'description':
        'Multiplies the inverses of the source and destination, resulting in a lighter output.',
  },
  'Color Dodge': {
    'flutterBlendMode': BlendMode.colorDodge,
    'description':
        'Brightens the destination by reducing contrast based on the source color.',
  },
  'Linear Dodge (Add)': {
    'flutterBlendMode': BlendMode.plus,
    'description': 'Adds the source and destination colors, clamping at white.',
  },
  'Overlay': {
    'flutterBlendMode': BlendMode.overlay,
    'description':
        'Combines multiply and screen modes: darkens dark areas, and lightens light areas.',
  },
  'Soft Light': {
    'flutterBlendMode': BlendMode.softLight,
    'description':
        'Softens the contrast by darkening or lightening the destination depending on the source.',
  },
  'Hard Light': {
    'flutterBlendMode': BlendMode.hardLight,
    'description':
        'Applies multiply or screen based on the source color’s intensity, creating a strong contrast.',
  },
  'Hue': {
    'flutterBlendMode': BlendMode.hue,
    'description':
        'Uses the source’s hue and the destination’s saturation and luminance.',
  },
  'Saturation': {
    'flutterBlendMode': BlendMode.saturation,
    'description':
        'Uses the source’s saturation and the destination’s hue and luminance.',
  },
  'Color': {
    'flutterBlendMode': BlendMode.color,
    'description':
        'Uses the source’s hue and saturation, but keeps the destination’s luminance.',
  },
  'Luminosity': {
    'flutterBlendMode': BlendMode.luminosity,
    'description':
        'Uses the source’s luminance and the destination’s hue and saturation.',
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
        items: supportedBlendModes.entries.map((entry) {
          final menuFlutterBlendMode =
              (entry.value['flutterBlendMode'] as BlendMode?) ??
                  BlendMode.srcOver;

          return PopupMenuItem<BlendMode>(
            value: menuFlutterBlendMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

String blendModeToText(BlendMode blendMode) {
  if (blendMode == BlendMode.srcOver) {
    return 'Normal';
  }
  return blendMode.name[0].toUpperCase() + blendMode.name.substring(1);
}
