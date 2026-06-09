import 'package:flutter/foundation.dart' show Key;

/// Shared widget keys used by tests and UI lookups across the app.
class Keys {
  static const Key floatActionSelector = Key('floating_action_selector');
  static const Key floatActionUndo = Key('floating_action_undo');
  static const Key floatActionRedo = Key('floating_action_redo');
  static const Key floatActionMenuToggle = Key('floating_action_menu_toggle');
  static const Key floatActionZoomIn = Key('floating_action_zoom_in');
  static const Key floatActionZoomOut = Key('floating_action_zoom_out');
  static const Key floatActionCenter = Key('floating_action_center');
  static const Key floatActionToggle = Key('floating_action_toggle');
  static const Key floatActionPaste = Key('floating_action_paste');
  static const Key mainMenuButton = Key('main-menu-button');
  static const Key mainMenuCanvasSize = Key('main-menu-canvas-size');
  static const Key sidePanelExportButton = Key('side-panel-export-button');
  static const Key appScreenshotBoundary = Key('app-screenshot-boundary');
  static const Key mainViewScreenshotBoundary = Key('main-view-screenshot-boundary');
  static const Key brushSizePreviewOverlay = Key('brush-size-preview-overlay');
  static const String gradientHandleKeyPrefixText = 'gradient_handle_';
  static const Key layerAddAboveButton = Key('layer-add-above-button');
  static const Key layerModifyButton = Key('layer-modify-button');
  static const Key layerToggleLockButton = Key('layer-toggle-lock-button');
  static const Key layerRenameTextField = Key('layer-rename-text-field');
  static const Key layerRenameApplyButton = Key('layer-rename-apply-button');
  static const Key canvasSettingsWidthField = Key('canvas-settings-width-field');
  static const Key canvasSettingsHeightField = Key('canvas-settings-height-field');
  static const Key canvasSettingsAspectRatioToggleButton = Key('canvas-settings-aspect-ratio-toggle-button');
  static const Key canvasSettingsApplyButton = Key('canvas-settings-apply-button');
  static const Key textEditorBoldButton = Key('text-editor-bold-button');
  static const Key textEditorItalicButton = Key('text-editor-italic-button');
  static const Key textEditorAlignmentDropdown = Key('text-editor-alignment-dropdown');
  static const Key magnifyingEyeDropperCloseButton = Key('magnifying-eye-dropper-close-button');
  static const Key magnifyingEyeDropperConfirmButton = Key('magnifying-eye-dropper-confirm-button');
  static const Key colorPickerModeToggle = Key('color-picker-mode-toggle');
  static const Key colorPickerModeSlidersButton = Key('color-picker-mode-sliders-button');
  static const Key colorPickerModeWheelButton = Key('color-picker-mode-wheel-button');
  static const Key colorPickerWheelSelector = Key('color-picker-wheel-selector');

  static const Key toolLine = Key('tool-line');
  static const Key toolRectangle = Key('tool-rectangle');
  static const Key toolCircle = Key('tool-circle');
  static const Key toolText = Key('tool-text');

  static const Key toolFill = Key('tool-fill');
  static const Key toolFillModeSolid = Key('tool-fill-mode-solid');
  static const Key toolFillModeLinear = Key('tool-fill-mode-linear');
  static const Key toolFillModeRadial = Key('tool-fill-mode-radial');
  static const Key toolFillHalftoneToggle = Key('tool-fill-halftone-toggle');
  static const Key toolFillHalftoneSlider = Key('tool-fill-halftone-slider');
  static const Key toolSmudge = Key('tool-smudge');
  static const Key toolBlurBrush = Key('tool-blur-brush');

  static const Key toolSelector = Key('tool-selector');
  static const Key toolSelectorModeRectangle = Key('tool-selector-mode-rectangle');
  static const Key toolSelectorModeCircle = Key('tool-selector-mode-circle');
  static const Key toolSelectorModeLine = Key('tool-selector-mode-line');
  static const Key toolSelectorModeLasso = Key('tool-selector-mode-lasso');
  static const Key toolSelectorModeWand = Key('tool-selector-mode-wand');
  static const Key toolSelectorCancel = Key('tool-selector-cancel');
  static const Key toolSelectorCopy = Key('tool-selector-copy');
  static const Key toolSelectorCut = Key('tool-selector-cut');

  static const Key toolPanelFillColor = Key('toolPanelFillColor');
  static const Key toolPanelHalftoneDotColor = Key('toolPanelHalftoneDotColor');
  static const Key toolPanelBrushColor1 = Key('toolPanelBrushColor1');
  static const Key toolPanelFontColor = Key('toolPanelFontColor');
  static const String gradientStopColorKeyPrefixText = 'gradient_stop_color_';
  static const Key gradientStopAddButton = Key('gradient_stop_add');
  static const String gradientStopPositionKeyPrefixText = 'gradient_stop_pos_';
  static const Key toolTransform = Key('tool-transform');

  static const Key effectsButton = Key('effects-button');
  static const Key effectIntensityPanelApplyButton = Key('effect-intensity-panel-apply-button');
  static const Key effectIntensityApplyButton = Key('effect-intensity-apply-button');
  static const Key effectIntensityCancelButton = Key('effect-intensity-cancel-button');
  static const Key effectIntensitySlider = Key('effect-intensity-slider');
  static const Key effectIntensityDialogSlider = Key('effect-intensity-dialog-slider');
  static const Key effectSizeSlider = Key('effect-size-slider');
  static const Key effectSizeDialogSlider = Key('effect-size-dialog-slider');

  static const Key toolBrushSizeTool = Key('tool-brush-size-tool');
  static const Key toolBrushSizeButton = Key('tool-brush-size-button');
  static const Key toolBrushSizeSlider = Key('tool-brush-size-slider');
  static const Key toolBrushIntensityTool = Key('tool-brush-intensity-tool');
  static const Key toolBrushIntensityButton = Key('tool-brush-intensity-button');
  static const Key toolBrushIntensitySlider = Key('tool-brush-intensity-slider');
}
