import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// Identifiers and defaults used when reading Photoshop PSD documents.
class PsdConstants {
  /// `lsct` section type for a regular, pixel-bearing layer.
  static const int layerTypeNormal = 0;

  /// `lsct` section type for an expanded group folder.
  static const int layerTypeOpenFolder = 1;

  /// `lsct` section type for a collapsed group folder.
  static const int layerTypeClosedFolder = 2;

  /// `lsct` section type for the hidden divider that bounds a group.
  ///
  /// PSD stores layers bottom-up, so this divider *opens* a group while
  /// walking in storage order and the folder record closes it.
  static const int layerTypeBoundingSectionDivider = 3;

  /// Name given to a layer whose PSD record stores no name.
  static const String unnamedLayerName = 'Layer';

  /// Name given to the single layer built from a flattened PSD's composite.
  static const String mergedLayerName = 'Background';
}

/// Maps PSD blend-mode keys to the closest Flutter [ui.BlendMode].
///
/// PSD stores blend modes as four-character codes (e.g. `mul ` for Multiply).
/// Modes Flutter's compositor has no equivalent for — Dissolve, the *Color
/// variants, Vivid/Linear/Pin Light, Hard Mix, Subtract and Divide — are absent
/// here and fall back to [ui.BlendMode.srcOver], matching how the ORA and TIFF
/// readers treat blend modes they cannot express.
const Map<int, ui.BlendMode> _psdBlendModes = <int, ui.BlendMode>{
  img.PsdBlendMode.passThrough: ui.BlendMode.srcOver,
  img.PsdBlendMode.normal: ui.BlendMode.srcOver,
  img.PsdBlendMode.darken: ui.BlendMode.darken,
  img.PsdBlendMode.multiply: ui.BlendMode.multiply,
  img.PsdBlendMode.colorBurn: ui.BlendMode.colorBurn,
  img.PsdBlendMode.lighten: ui.BlendMode.lighten,
  img.PsdBlendMode.screen: ui.BlendMode.screen,
  img.PsdBlendMode.colorDodge: ui.BlendMode.colorDodge,
  img.PsdBlendMode.overlay: ui.BlendMode.overlay,
  img.PsdBlendMode.softLight: ui.BlendMode.softLight,
  img.PsdBlendMode.hardLight: ui.BlendMode.hardLight,
  img.PsdBlendMode.difference: ui.BlendMode.difference,
  img.PsdBlendMode.exclusion: ui.BlendMode.exclusion,
  img.PsdBlendMode.hue: ui.BlendMode.hue,
  img.PsdBlendMode.saturation: ui.BlendMode.saturation,
  img.PsdBlendMode.color: ui.BlendMode.color,
  img.PsdBlendMode.luminosity: ui.BlendMode.luminosity,
};

/// Returns the [ui.BlendMode] for a PSD blend-mode key.
///
/// Unknown or unmappable keys (and null, for records without one) resolve to
/// [ui.BlendMode.srcOver] so the layer still composites normally.
ui.BlendMode blendModeFromPsdBlendMode(int? psdBlendMode) {
  if (psdBlendMode == null) {
    return ui.BlendMode.srcOver;
  }
  return _psdBlendModes[psdBlendMode] ?? ui.BlendMode.srcOver;
}
