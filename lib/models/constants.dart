import 'package:flutter/material.dart';

/// Application color constants for consistent theming
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF2196F3); // Light blue
  static const Color secondary = Color(0xFF1976D2); // Blue
  static const Color accent = Color(0xFF42A5F5); // Lighter blue

  // Background colors
  static const Color background = Color(0xFF121212); // Dark background
  static const Color surface = Color(0xFF1E1E1E); // Surface color
  static const Color surfaceVariant = Color(0xFF2D2D2D); // Variant surface

  // Panel colors
  static const Color panelBackground = Color(0xFF2D2D2D); // Side panel background
  static const Color divider = Color(0xFF424242); // Divider color

  // Button colors
  static const Color floatingButtonBackground = Color(0xFF424242); // Floating button background
  static const Color floatingButtonForeground = Colors.white;

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF666666);

  // Interactive colors
  static const Color hover = Color(0xFF333333);
  static const Color selected = Color(0xFF2196F3);
  static const Color pressed = Color(0xFF1976D2);
}

class Keys {
  static Key floatActionZoomIn = const Key('floating_action_zoom_in');
  static Key floatActionZoomOut = const Key('floating_action_zoom_out');
  static Key floatActionCenter = const Key('floating_action_center');
  static Key floatActionToggle = const Key('floating_action_toggle');
  static String gradientHandleKeyPrefixText = 'gradient_handle_';

  static Key toolFill = const Key('tool-fill');
  static Key toolFillModeSolid = const Key('tool-fill-mode-solid');
  static Key toolFillModeLinear = const Key('tool-fill-mode-linear');
  static Key toolFillModeRadial = const Key('tool-fill-mode-radial');

  static Key toolSelector = const Key('tool-selector');
  static Key toolSelectorModeRectangle = const Key('tool-selector-mode-rectangle');
  static Key toolSelectorModeCircle = const Key('tool-selector-mode-circle');
  static Key toolSelectorModeLasso = const Key('tool-selector-mode-lasso');
  static Key toolSelectorModeWand = const Key('tool-selector-mode-wand');
  static Key toolSelectorCancel = const Key('tool-selector-cancel');

  static Key toolPanelFillColor = const Key('toolPanelFillColor');
  static Key toolPanelBrushColor1 = const Key('toolPanelBrushColor1');
  static Key toolPanelFontColor = const Key('toolPanelFontColor');
}
