import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';

/// Collection of color utility functions for:
/// - Color manipulation (tinting, brightness, opacity)
/// - Format conversion (hex, HSL, RGB)
/// - Contrast calculation
/// - Theme-aware color selection
/// - Color state management

/// Adjusts the brightness of the input color to the specified value within the valid range (0.0 to 1.0).
Color adjustBrightness(final Color color, double brightness) {
  // Ensure brightness is within valid range
  brightness = brightness.clamp(0.0, 1.0);

  // Convert color to HSL
  HSLColor hslColor = HSLColor.fromColor(color);

  // Adjust lightness component
  hslColor = hslColor.withLightness(brightness);

  // Convert back to RGB
  return hslColor.toColor();
}

/// Possible states
enum ColorState {
  success,
  warning,
  error,
  disabled,
  quantityPositive,
  quantityNegative,
}

/// Converts a given [Color] object to a hexadecimal string representation.
///
/// The [color] parameter represents the color to be converted.
/// The [alphaFirst] parameter determines whether the alpha value should be placed before the RGB values in the hexadecimal string. By default, it is set to false.
/// The [includeAlpha] parameter determines whether the alpha value should be included in the hexadecimal string. By default, it is set to true.
///
/// Returns the hexadecimal string representation of the color, including the alpha value if specified.
/// If [includeAlpha] is false, the returned string will only contain the RGB values.
/// If [alphaFirst] is true, the returned string will have the alpha value placed before the RGB values.
/// Otherwise, the returned string will have the RGB values followed by the alpha value.
///
String colorToHexString(
  final Color color, {
  final bool alphaFirst = true,
  final bool includeAlpha = true,
  final String seperator = '',
}) {
  final List<String> components = getColorComponentsAsHex(color, includeAlpha, alphaFirst);
  return '#${components.join(seperator)}';
}

/// Returns the color components (alpha, red, green, blue) as an array of hexadecimal strings.
///
/// The [color] parameter represents the color to be converted.
/// The returned array contains the alpha, red, green, and blue components as hexadecimal strings.
///
/// Returns an array of hexadecimal strings representing the color components.
List<String> getColorComponentsAsHex(
  final Color color, [
  final bool includeAlpha = true,
  final bool alphaIsFirst = true,
]) {
  final String alpha = (color.a * AppLimits.rgbChannelMax)
      .toInt()
      .toRadixString(AppMath.hexRadix)
      .padLeft(AppMath.hexPad, '0')
      .toUpperCase();
  final String red = (color.r * AppLimits.rgbChannelMax)
      .toInt()
      .toRadixString(AppMath.hexRadix)
      .padLeft(AppMath.hexPad, '0')
      .toUpperCase();
  final String green = (color.g * AppLimits.rgbChannelMax)
      .toInt()
      .toRadixString(AppMath.hexRadix)
      .padLeft(AppMath.hexPad, '0')
      .toUpperCase();
  final String blue = (color.b * AppLimits.rgbChannelMax)
      .toInt()
      .toRadixString(AppMath.hexRadix)
      .padLeft(AppMath.hexPad, '0')
      .toUpperCase();
  if (alphaIsFirst) {
    return <String>[
      if (includeAlpha) alpha,
      red,
      green,
      blue,
    ];
  } else {}
  return <String>[
    red,
    green,
    blue,
    if (includeAlpha) alpha,
  ];
}

/// Calculates the contrast color based on the luminance of the input color.
///
/// The [color] parameter represents the color for which the contrast color will be calculated.
/// The luminance of the [color] is calculated using the formula: (0.299 * red + 0.587 * green + 0.114 * blue) / 255.
/// If the calculated luminance is greater than 0.5, the contrast color is set to black. Otherwise, it is set to white.
///
/// Returns the contrast color as a [Color] object.
///
Color contrastColor(final Color color) {
  // Calculate the luminance of the color including alpha
  final double luminance =
      (0.299 * (color.r * AppLimits.rgbChannelMax) +
          0.587 * (color.g * AppLimits.rgbChannelMax) +
          0.114 * (color.b * AppLimits.rgbChannelMax)) /
      AppLimits.rgbChannelMax;
  final double alphaFactor = color.a;

  // Determine whether to make the contrast color black or white based on the luminance and alpha
  final Color contrastColor = (luminance * alphaFactor) > AppVisual.half ? Colors.black : Colors.white;

  return contrastColor;
}

/// Returns a Color object based on a given hexadecimal color string.
///
/// The hexadecimal color string can be in the format "#RRGGBB" or "#AARRGGBB".
/// If the hexadecimal color string is in the format "#RRGGBB", the alpha value is set to 255 (fully opaque).
/// If the hexadecimal color string is in the format "#AARRGGBB", the alpha value is parsed from the string.
/// If the hexadecimal color string is not in a valid format, the function returns Colors.transparent.
///
/// @param hexColor The hexadecimal color string to convert to a Color object.
/// @return The Color object representing the given hexadecimal color string, or Colors.transparent if the string is not in a valid format.
///
Color getColorFromString(final String hexColor) {
  String newHexColor = hexColor.trim().replaceAll('#', '');
  if (newHexColor.length == AppLimits.hexRgbLength) {
    newHexColor = 'FF$newHexColor';
  }
  if (newHexColor.length == AppLimits.hexArgbLength) {
    return Color(int.parse('0x$newHexColor'));
  }
  return Colors.transparent;
}

/// Converts HSV (Hue, Saturation, Value) color representation to a [Color] object.
///
/// The [hue] parameter represents the hue of the color in degrees (0.0 to 360.0).
/// The [brightness] parameter represents the brightness (value) of the color as a
/// percentage (0.0 to 1.0).
///
/// Returns a [Color] object corresponding to the given HSV values.
Color hsvToColor(final double hue, final double brightness) {
  final Color color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
  return adjustBrightness(color, brightness);
}

/// Represents a color usage with a specific color and percentage.
///
/// The [ColorUsage] class is used to encapsulate information about a color usage,
/// including the color itself and the percentage of that color usage.
///
/// The [color] property represents the color to be used, and the [percentage] property
/// represents the percentage of that color usage, ranging from 0.0 to 1.0.
///
/// This class is typically used in contexts where color usage information needs to be
/// tracked and managed, such as in UI design or data visualization.
class ColorUsage {
  ColorUsage(this.color, this.percentage);
  Color color = Colors.black;
  double percentage = 1.0; // from 0 to 1

  /// Returns this usage value formatted as a percentage string.
  ///
  /// Uses [decimals] fractional digits and returns "<0.1%" for tiny values
  /// when very low precision is requested.
  String toStringPercentage([final int decimals = AppMath.triple]) {
    if (decimals < AppMath.pair && this.percentage < AppMath.tinyPercentage) {
      return '<0.1%';
    }
    return '${(this.percentage * AppLimits.percentMax).toStringAsFixed(decimals)}%';
  }
}
