// ignore: fcheck_magic_numbers
import 'dart:ui' show Color;

/// Raw color palette and semantic color constants for consistent theming.
///
/// Palette values mirror Material defaults and semantic values map those
/// colors to application roles.
class AppColors {
  // Core palette
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  // Base hues
  static const Color red = Color(0xFFF44336);
  static const Color blue = Color(0xFF2196F3);
  static const Color blueShade100 = Color(0xFFBBDEFB);
  static const Color green = Color(0xFF4CAF50);
  static const Color orange = Color(0xFFFF9800);
  static const Color yellow = Color(0xFFFFEB3B);
  static const Color purple = Color(0xFF9C27B0);

  // Grey scale
  static const Color grey = Color(0xFF9E9E9E);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);

  // Overlays
  static const Color overlayDark = Color(0xC8000000);
  static const Color overlayLight = Color(0xC8FFFFFF);
  static const Color overlayBorder = Color(0x59FFFFFF);
  static const Color scrim = Color(0x80000000);

  // Primary colors
  static const Color primary = blue; // Light blue
  static const Color secondary = Color(0xFF1976D2); // Blue
  static const Color accent = Color(0xFF42A5F5); // Lighter blue

  // Background colors
  static const Color background = Color.fromARGB(255, 21, 21, 21); // Dark background
  static const Color surface = Color.fromARGB(255, 30, 30, 30); // Surface color
  static const Color surfaceVariant = Color.fromARGB(255, 45, 45, 45); // Variant surface

  // Panel colors
  static const Color panelBackground = surfaceVariant; // Side panel background
  static const Color divider = grey800; // Divider color

  // Shell chrome colors (main frame + split dividers)
  static const Color shellChromeBackground = background;
  static const Color shellChromeDivider = divider;
  static const Color shellChromeDividerHighlight = grey700;

  // Button colors
  static const Color floatingButtonBackground = Color(0xFF424242); // Floating button background
  static const Color floatingButtonForeground = white;

  // ITU-R BT.601 luma coefficients for perceived brightness
  static const double lumaRedWeight = 0.299;
  static const double lumaGreenWeight = 0.587;
  static const double lumaBlueWeight = 0.114;

  // Text colors
  static const Color textPrimary = white;
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF666666);

  // Interactive colors
  static const Color hover = Color(0xFF333333);
  static const Color selected = primary;
  static const Color pressed = secondary;
  static const Color layerHiddenWarning = Color.fromARGB(255, 241, 85, 85);

  // Overlay button colors
  static const Color buttonBorder = overlayLight;
  static const Color buttonBackground = overlayDark;
  static const Color buttonSelected = selected;
  static const Color buttonEnable = textPrimary;
  static const Color buttonDisable = grey400;
  static const Color buttonDanger = red;

  // Transform handle colors
  static const Color transformCornerHandle = Color(0xFFFF9800);
  static const Color transformEdgeHandle = Color(0xFFFFC107);

  // Gradient defaults
  static const Color gradientDefaultStart = Color(0xFF4FC3F7); // Light blue
  static const Color gradientDefaultEnd = Color(0xFF0D47A1); // Dark blue
}
