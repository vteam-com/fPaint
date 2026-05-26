import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/app_provider_tools.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/brush_style_picker.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/effect_intensity_controls.dart';
import 'package:fpaint/widgets/gradient_color_list_editor.dart';
import 'package:fpaint/widgets/halftone_size_picker.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/text_attributes_widget.dart';
import 'package:fpaint/widgets/tolerance_picker.dart';
import 'package:fpaint/widgets/tool_attribute_widget.dart';
import 'package:fpaint/widgets/top_colors.dart';

/// Represents a panel that displays tools for the application.
/// The ToolsPanel is a stateless widget that displays a set of tools
/// that the user can interact with to perform various actions in the
/// application. It includes a list of tools, as well as any associated
/// attributes or settings for the selected tool.
class ToolsPanel extends StatelessWidget {
  const ToolsPanel({
    super.key,
    required this.minimal,
  });

  /// A boolean indicating whether the panel is in minimal mode.
  final bool minimal;
  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: true);
    final ActionType selectedTool = appProvider.selectedAction;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Wrap(
            spacing: minimal ? AppSpacing.thin : AppSpacing.small,
            runSpacing: minimal ? AppSpacing.thin : AppSpacing.small,
            alignment: WrapAlignment.center,
            children: getListOfTools(context),
          ),
          AnimatedSwitcher(
            duration: AppDefaults.toolPanelRevealAnimationDuration,
            reverseDuration: AppDefaults.toolPanelRevealAnimationDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (final Widget child, final Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<ActionType>(selectedTool),
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.medium),
                child: Wrap(
                  runSpacing: minimal ? AppSpacing.small : AppSpacing.thin,
                  alignment: WrapAlignment.center,
                  children: getWidgetForSelectedTool(context: context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Adds a tool option for brush or fill color.
  void addToolOptionColor(
    final List<Widget> widgets,
    final AppProvider appProvider,
    final BuildContext context,
    final bool isBrush,
  ) {
    final AppLocalizations l10n = context.l10n;
    final String name = isBrush ? l10n.brushColor : l10n.fillColor;
    final Key previewKey = isBrush ? Keys.toolPanelBrushColor1 : Keys.toolPanelFillColor;
    final Color color = isBrush ? appProvider.brushColor : appProvider.fillColor;
    final bool isPickFromCanvasActive = isBrush
        ? appProvider.eyeDropPositionForBrush != null
        : appProvider.eyeDropPositionForFill != null;
    _addToolOptionColor(
      widgets: widgets,
      context: context,
      name: name,
      previewKey: previewKey,
      color: color,
      isPickFromCanvasActive: isPickFromCanvasActive,
      onColorChanged: (final Color selectedColor) {
        if (isBrush) {
          appProvider.brushColor = selectedColor;
        } else {
          appProvider.fillColor = selectedColor;
        }
      },
      onPickFromCanvas: () {
        if (isBrush) {
          appProvider.eyeDropPositionForFill = null;
          appProvider.eyeDropPositionForBrush = appProvider.canvasCenter;
        } else {
          appProvider.eyeDropPositionForBrush = null;
          appProvider.eyeDropPositionForFill = appProvider.canvasCenter;
        }
        appProvider.update();
      },
    );
  }

  /// Adds a tool option for color tolerance.
  Widget addToolOptionTolerance(
    final BuildContext context,
    final AppProvider appProvider,
  ) {
    final AppLocalizations l10n = context.l10n;

    return ToolAttributeWidget(
      compact: minimal,
      name: l10n.colorTolerance,
      childLeft: AppButtonIcon(
        icon: AppIcon.support,
        onPressed: () {
          showTolerancePicker(context, appProvider.tolerance, (final int newValue) {
            appProvider.tolerance = newValue;
          });
        },
      ),
      childRight: minimal
          ? null
          : TolerancePicker(
              title: l10n.tolerance,
              value: appProvider.tolerance,
              onChanged: (final int value) {
                appProvider.tolerance = value;
              },
            ),
    );
  }

  /// Adds a tool option for top colors.
  void addToolOptionTopColors(
    final List<Widget> widgets,
    final LayersProvider layers,
    final AppProvider appProvider,
    final bool minimal,
    final AppLocalizations l10n,
  ) {
    widgets.add(
      ToolAttributeWidget(
        compact: minimal,
        name: l10n.topColors(layers.topColors.length),
        childRight: ListenableBuilder(
          listenable: layers,
          builder: (final BuildContext _, final Widget? _) {
            return TopColors(
              colorUsages: layers.topColors,
              onRefresh: layers.evaluateTopColor,
              onColorPicked: (final Color color) {
                if (appProvider.selectedAction == ActionType.rectangle ||
                    appProvider.selectedAction == ActionType.circle ||
                    appProvider.selectedAction == ActionType.fill) {
                  appProvider.fillColor = color;
                } else {
                  appProvider.brushColor = color;
                }
              },
              minimal: minimal,
              showHeader: false,
              autoRefreshOnIdle: true,
              refreshRevision: layers.topColorsRefreshRevision,
            );
          },
        ),
      ),
    );
  }

  /// Returns a list of widgets representing the available tools.
  List<Widget> getListOfTools(
    final BuildContext context,
  ) {
    final AppProvider appProvider = AppProvider.of(context);
    final AppLocalizations l10n = context.l10n;
    final ActionType selectedTool = appProvider.selectedAction;

    final List<Widget> tools = <Widget>[
      _buildActionPicker(
        minimal: minimal,
        name: l10n.toolPencil,
        icon: ActionType.pencil.icon,
        isSelected: selectedTool == ActionType.pencil,
        onPressed: () {
          appProvider.selectedAction = ActionType.pencil;
        },
      ),
      _buildActionPicker(
        minimal: minimal,
        name: l10n.toolBrush,
        icon: ActionType.brush.icon,
        isSelected: selectedTool == ActionType.brush,
        onPressed: () {
          appProvider.selectedAction = ActionType.brush;
        },
      ),
      _buildActionPicker(
        key: Keys.toolLine,
        minimal: minimal,
        name: l10n.toolLine,
        icon: ActionType.line.icon,
        isSelected: selectedTool == ActionType.line,
        onPressed: () {
          appProvider.selectedAction = ActionType.line;
        },
      ),
      _buildActionPicker(
        key: Keys.toolRectangle,
        minimal: minimal,
        name: l10n.toolRectangle,
        icon: ActionType.rectangle.icon,
        isSelected: selectedTool == ActionType.rectangle,
        onPressed: () {
          appProvider.selectedAction = ActionType.rectangle;
        },
      ),
      _buildActionPicker(
        key: Keys.toolCircle,
        minimal: minimal,
        name: l10n.toolCircle,
        icon: ActionType.circle.icon,
        isSelected: selectedTool == ActionType.circle,
        onPressed: () {
          appProvider.selectedAction = ActionType.circle;
        },
      ),
      _buildActionPicker(
        key: Keys.toolFill,
        minimal: minimal,
        name: l10n.toolPaintBucket,
        icon: ActionType.fill.icon,
        isSelected: selectedTool == ActionType.fill,
        onPressed: () {
          appProvider.selectedAction = ActionType.fill;
        },
      ),
      _buildActionPicker(
        minimal: minimal,
        name: l10n.toolEraser,
        icon: ActionType.eraser.icon,
        isSelected: selectedTool == ActionType.eraser,
        onPressed: () {
          appProvider.selectedAction = ActionType.eraser;
        },
      ),
      _buildActionPicker(
        key: Keys.toolText,
        minimal: minimal,
        name: l10n.toolText,
        icon: ActionType.text.icon,
        isSelected: selectedTool == ActionType.text,
        onPressed: () {
          appProvider.selectedAction = ActionType.text;
        },
      ),
      _buildActionPicker(
        key: Keys.toolSelector,
        minimal: minimal,
        name: l10n.toolSelector,
        icon: ActionType.selector.icon,
        isSelected: selectedTool == ActionType.selector,
        onPressed: () {
          appProvider.selectedAction = ActionType.selector;
        },
      ),

      // Paste from clipboard
      _buildActionPicker(
        minimal: minimal,
        name: l10n.paste,
        icon: AppIcon.clipboardPaste,
        color: AppColors.textPrimary,
        onPressed: () => appProvider.paste(),
      ),
    ];
    return tools;
  }

  /// Returns a list of widgets representing the attributes for the selected tool.
  List<Widget> getWidgetForSelectedTool({
    required final BuildContext context,
  }) {
    final List<Widget> widgets = <Widget>[];
    final AppProvider appProvider = AppProvider.of(context, listen: true);
    final AppLocalizations l10n = context.l10n;
    final LayersProvider layers = LayersProvider.of(context);
    final ActionType selectedTool = appProvider.selectedAction;

    switch (selectedTool) {
      case ActionType.fill:
        widgets.add(
          ToolAttributeWidget(
            compact: minimal,
            name: l10n.toolFill,
            childRight: Wrap(
              alignment: WrapAlignment.center,
              children: <Widget>[
                //
                // Selection using Rectangle
                //
                _buildActionPicker(
                  key: Keys.toolFillModeSolid,
                  minimal: minimal,
                  name: l10n.toolSolid,
                  icon: AppIcon.square,
                  isSelected: appProvider.fillModel.mode == FillMode.solid,
                  onPressed: () {
                    appProvider.fillModel.mode = FillMode.solid;
                    appProvider.update();
                  },
                ),
                //
                // Linear Gradient
                //
                _buildActionPicker(
                  key: Keys.toolFillModeLinear,
                  minimal: minimal,
                  name: l10n.toolLinearGradient,
                  icon: AppIcon.fillLinear,
                  isSelected: appProvider.fillModel.mode == FillMode.linear,
                  onPressed: () {
                    appProvider.fillModel.mode = FillMode.linear;
                    appProvider.update();
                    appProvider.updateGradientFill();
                  },
                ),
                //
                // Radial Gradient
                //
                _buildActionPicker(
                  key: Keys.toolFillModeRadial,
                  minimal: minimal,
                  name: l10n.toolRadialGradient,
                  icon: AppIcon.fillRadial,
                  isSelected: appProvider.fillModel.mode == FillMode.radial,
                  onPressed: () {
                    appProvider.fillModel.mode = FillMode.radial;
                    appProvider.update();
                    appProvider.updateGradientFill();
                  },
                ),
              ],
            ),
          ),
        );
        // For solid mode show a single fill-color picker.
        // When halftone is enabled, that same color becomes the dot color.
        // For gradient modes show the multi-stop color list editor.
        if (appProvider.fillModel.mode == FillMode.solid) {
          addToolOptionColor(widgets, appProvider, context, false);
          _addHalftoneSlider(widgets, appProvider, context);
        } else {
          _addGradientColorEditor(widgets, appProvider, context);
          _addHalftoneSlider(widgets, appProvider, context);
        }
        widgets.add(addToolOptionTolerance(context, appProvider));
        addToolOptionTopColors(widgets, layers, appProvider, minimal, l10n);
        break;

      case ActionType.text:
        widgets.add(
          const TextAttributesWidget(
            minimal: false,
          ),
        );
        break;
      case ActionType.selector:
        widgets.add(
          ToolAttributeWidget(
            compact: minimal,
            name: l10n.toolSelector,
            childRight: Wrap(
              alignment: WrapAlignment.center,
              children: <Widget>[
                //
                // Selection using Rectangle
                //
                _buildActionPicker(
                  key: Keys.toolSelectorModeRectangle,
                  minimal: minimal,
                  name: l10n.toolRectangle,
                  icon: AppIcon.selectorSquare,
                  isSelected: appProvider.selectorModel.mode == SelectorMode.rectangle,
                  onPressed: () {
                    appProvider.selectorModel.mode = SelectorMode.rectangle;
                    appProvider.update();
                  },
                ),
                //
                // Selection using Circle
                //
                _buildActionPicker(
                  key: Keys.toolSelectorModeCircle,
                  minimal: minimal,
                  name: l10n.toolCircle,
                  icon: AppIcon.selectorCircle,
                  isSelected: appProvider.selectorModel.mode == SelectorMode.circle,
                  onPressed: () {
                    appProvider.selectorModel.mode = SelectorMode.circle;
                    appProvider.update();
                  },
                ),
                //
                // Selection using Drawing
                //
                _buildActionPicker(
                  key: Keys.toolSelectorModeLasso,
                  minimal: minimal,
                  name: l10n.toolLasso,
                  icon: AppIcon.lasso,
                  isSelected: appProvider.selectorModel.mode == SelectorMode.lasso,
                  onPressed: () {
                    appProvider.selectorModel.mode = SelectorMode.lasso;
                    appProvider.update();
                  },
                ),
                //
                // Selection using magic wand
                //
                _buildActionPicker(
                  key: Keys.toolSelectorModeWand,
                  minimal: minimal,
                  name: l10n.toolMagic,
                  icon: AppIcon.autoFixHigh,
                  isSelected: appProvider.selectorModel.mode == SelectorMode.wand,
                  onPressed: () {
                    appProvider.selectorModel.mode = SelectorMode.wand;
                    appProvider.update();
                  },
                ),
                if (appProvider.selectorModel.isVisible)
                  _buildActionPicker(
                    key: Keys.toolSelectorCancel,
                    minimal: minimal,
                    name: l10n.cancel,
                    icon: AppIcon.selectorCancel,
                    color: AppColors.layerHiddenWarning,
                    onPressed: () {
                      appProvider.cancelEffectPreview();
                      appProvider.selectorModel.clear();
                      appProvider.update();
                    },
                  ),
                if (appProvider.selectorModel.mode == SelectorMode.wand) addToolOptionTolerance(context, appProvider),

                if (appProvider.selectorModel.isVisible) const AppDivider(),

                if (appProvider.selectorModel.isVisible)
                  _buildActionPicker(
                    minimal: minimal,
                    name: l10n.toolReplace,
                    icon: AppIcon.selectorReplace,
                    isSelected: appProvider.selectorModel.math == SelectorMath.replace,
                    onPressed: () {
                      appProvider.selectorModel.math = SelectorMath.replace;
                      appProvider.update();
                    },
                  ),

                if (appProvider.selectorModel.isVisible)
                  _buildActionPicker(
                    minimal: minimal,
                    name: l10n.toolAdd,
                    icon: AppIcon.selectorAdd,
                    isSelected: appProvider.selectorModel.math == SelectorMath.add,
                    onPressed: () {
                      appProvider.selectorModel.math = SelectorMath.add;
                      appProvider.update();
                    },
                  ),

                if (appProvider.selectorModel.isVisible)
                  _buildActionPicker(
                    minimal: minimal,
                    name: l10n.toolRemove,
                    icon: AppIcon.selectorRemove,
                    isSelected: appProvider.selectorModel.math == SelectorMath.remove,
                    onPressed: () {
                      appProvider.selectorModel.math = SelectorMath.remove;
                      appProvider.update();
                    },
                  ),

                if (appProvider.selectorModel.isVisible) const AppDivider(),

                if (appProvider.selectorModel.isVisible)
                  _buildActionPicker(
                    minimal: minimal,
                    name: l10n.toolInvert,
                    icon: AppIcon.selectorInvert,
                    onPressed: () {
                      appProvider.selectorModel.invert(
                        Rect.fromLTWH(
                          0,
                          0,
                          layers.size.width,
                          layers.size.height,
                        ),
                      );
                      appProvider.update();
                    },
                  ),

                if (appProvider.selectorModel.isVisible)
                  _buildActionPicker(
                    minimal: minimal,
                    name: l10n.toolCrop,
                    icon: AppIcon.canvasCrop,
                    onPressed: () {
                      final ShellProvider shellProvider = ShellProvider.of(context);
                      shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
                      shellProvider.update();

                      appProvider.crop();
                      appProvider.update();
                    },
                  ),

                if (appProvider.selectorModel.isVisible) const AppDivider(),
                if (appProvider.selectorModel.isVisible)
                  _EffectsSection(
                    minimal: minimal,
                    l10n: l10n,
                    appProvider: appProvider,
                  ),
              ],
            ),
          ),
        );

        break;

      default:
        final String title = appProvider.selectedAction == ActionType.pencil ? l10n.pencilSize : l10n.brushSize;
        final double min = appProvider.selectedAction == ActionType.pencil ? 1 : AppInteraction.minCanvasScale;
        final double max = AppLimits.percentMax.toDouble();

        // Brush Size
        if (selectedTool.isSupported(ActionOptions.brushSize)) {
          widgets.add(
            ToolAttributeWidget(
              key: Keys.toolBrushSizeTool,
              compact: minimal,
              name: title,
              childLeft: AppButtonIcon(
                key: Keys.toolBrushSizeButton,
                icon: AppIcon.lineWeight,
                constraints: minimal ? const BoxConstraints() : null,
                padding: minimal ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.small),
                onPressed: () {
                  showBrushSizePicker(
                    context: context,
                    title: title,
                    value: appProvider.brushSize,
                    min: min,
                    max: max,
                    onChanged: (final double newValue) {
                      appProvider.brushSize = newValue;
                    },
                  );
                },
              ),
              childRight: minimal
                  ? null
                  : BrushSizePicker(
                      key: Keys.toolBrushSizeSlider,
                      title: title,
                      value: appProvider.brushSize,
                      min: min,
                      max: max,
                      onChanged: (final double value) {
                        appProvider.brushSize = value;
                      },
                    ),
            ),
          );
        }

        // Brush Style
        if (selectedTool.isSupported(ActionOptions.brushStyle)) {
          widgets.add(
            ToolAttributeWidget(
              compact: minimal,
              name: l10n.brushStyle,
              childLeft: AppButtonIcon(
                icon: AppIcon.lineStyle,
                constraints: minimal ? const BoxConstraints() : null,
                padding: minimal ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.small),
                onPressed: () {
                  showBrushStylePicker(
                    context,
                    appProvider.brushStyle,
                    (final BrushStyle selectedBrushStyle) => appProvider.brushStyle = selectedBrushStyle,
                  );
                },
              ),
              childRight: minimal
                  ? null
                  : brushStyleDropDown(
                      context,
                      appProvider.brushStyle,
                      (final BrushStyle selectedBrushStyle) => appProvider.brushStyle = selectedBrushStyle,
                    ),
            ),
          );
        }

        // Brush color
        if (selectedTool.isSupported(ActionOptions.brushColor)) {
          addToolOptionColor(widgets, appProvider, context, true);
        }

        // Fill Color
        if (selectedTool.isSupported(ActionOptions.colorFill)) {
          addToolOptionColor(widgets, appProvider, context, false);
        }

        // Color Tolerance used by Fill and Magic wand
        if (selectedTool.isSupported(ActionOptions.tolerance)) {
          widgets.add(addToolOptionTolerance(context, appProvider));
        }

        // Top colors
        if (selectedTool.isSupported(ActionOptions.topColors)) {
          addToolOptionTopColors(widgets, layers, appProvider, minimal, l10n);
        }
    }

    return widgets;
  }

  /// Adds the gradient color list editor for linear/radial fill modes.
  void _addGradientColorEditor(
    final List<Widget> widgets,
    final AppProvider appProvider,
    final BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    widgets.add(
      ToolAttributeWidget(
        compact: minimal,
        name: l10n.gradientColors,
        childLeft: minimal
            ? colorPreviewWithTransparentPaper(
                key: Keys.toolPanelFillColor,
                minimal: minimal,
                color: appProvider.fillModel.gradientStopColors.first,
                onPressed: () {
                  showColorPicker(
                    context: context,
                    title: l10n.gradientColors,
                    color: appProvider.fillModel.gradientStopColors.first,
                    onSelectedColor: (final Color picked) {
                      appProvider.fillModel.gradientStopColors[0] = picked;
                      if (appProvider.fillModel.gradientPoints.isNotEmpty) {
                        appProvider.fillModel.gradientPoints.first.color = picked;
                      }
                      appProvider.updateGradientFill();
                    },
                  );
                },
              )
            : null,
        childRight: minimal
            ? null
            : GradientColorListEditor(
                fillModel: appProvider.fillModel,
                onChanged: appProvider.updateGradientFill,
              ),
      ),
    );
  }

  /// Adds the halftone size slider for flood fills.
  void _addHalftoneSlider(
    final List<Widget> widgets,
    final AppProvider appProvider,
    final BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    final bool halftoneEnabled = appProvider.fillModel.halftoneEnabled;
    final int halftonePercent = appProvider.fillModel.halftoneMaxDotSizePercent;

    void updateHalftonePercent(final int value) {
      appProvider.fillModel.halftoneMaxDotSizePercent = value;
      appProvider.updateGradientFill();
      appProvider.update();
    }

    void updateHalftoneEnabled(final bool value) {
      appProvider.fillModel.halftoneEnabled = value;
      appProvider.updateGradientFill();
      appProvider.update();
    }

    widgets.add(
      ToolAttributeWidget(
        compact: minimal,
        name: l10n.toolHalftone,
        enabled: halftoneEnabled,
        onEnabledChanged: updateHalftoneEnabled,
        enabledToggleKey: Keys.toolFillHalftoneToggle,
        childLeft: AppButtonIcon(
          icon: AppIcon.checkCircle,
          isSelected: halftoneEnabled,
          constraints: minimal ? const BoxConstraints() : null,
          padding: EdgeInsets.all(minimal ? AppSpacing.thin : AppSpacing.small),
          tooltip: l10n.toolHalftone,
          onPressed: () {
            showHalftoneSizePicker(
              context: context,
              value: halftonePercent,
              onChanged: updateHalftonePercent,
            );
          },
        ),
        childRight: minimal
            ? null
            : AppSlider(
                key: Keys.toolFillHalftoneSlider,
                valueLabel: l10n.percentageValue(halftonePercent),
                value: halftonePercent.toDouble(),
                min: AppMath.zero.toDouble(),
                max: AppLimits.percentMax.toDouble(),
                divisions: AppLimits.sliderDivisions,
                onChanged: halftoneEnabled ? (final double value) => updateHalftonePercent(value.toInt()) : null,
              ),
      ),
    );
  }

  /// Adds a color-related tool option row with preview, picker, and selector.
  void _addToolOptionColor({
    required final List<Widget> widgets,
    required final BuildContext context,
    required final String name,
    required final Key previewKey,
    required final Color color,
    required final bool isPickFromCanvasActive,
    required final ValueChanged<Color> onColorChanged,
    required final VoidCallback onPickFromCanvas,
  }) {
    widgets.add(
      ToolAttributeWidget(
        compact: minimal,
        name: name,
        childLeft: Column(
          children: <Widget>[
            colorPreviewWithTransparentPaper(
              key: previewKey,
              minimal: minimal,
              color: color,
              onPressed: () {
                showColorPicker(
                  context: context,
                  title: name,
                  color: color,
                  onSelectedColor: onColorChanged,
                );
              },
            ),
            if (!minimal)
              AppButtonIcon(
                icon: AppIcon.eyedropper,
                isSelected: isPickFromCanvasActive,
                onPressed: onPickFromCanvas,
              ),
          ],
        ),
        childRight: minimal
            ? null
            : ColorSelector(
                color: color,
                onColorChanged: onColorChanged,
              ),
      ),
    );
  }
}

/// Side-panel section listing all [SelectionEffect] buttons with effect sliders
/// so the user can tune preview parameters before applying an effect.
class _EffectsSection extends StatefulWidget {
  const _EffectsSection({
    required this.minimal,
    required this.l10n,
    required this.appProvider,
  });

  final AppProvider appProvider;
  final AppLocalizations l10n;
  final bool minimal;

  @override
  State<_EffectsSection> createState() => _EffectsSectionState();
}

class _EffectsSectionState extends State<_EffectsSection> {
  @override
  Widget build(final BuildContext context) {
    final SelectionEffect? selectedEffect = widget.appProvider.effectPreviewModel.effect;
    final bool hasEffectPreview = widget.appProvider.effectPreviewModel.isVisible;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: widget.minimal ? AppSpacing.thin : AppSpacing.small,
          runSpacing: widget.minimal ? AppSpacing.thin : AppSpacing.small,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final SelectionEffect effect in SelectionEffect.values)
              _buildActionPicker(
                minimal: widget.minimal,
                name: effectLabel(widget.l10n, effect),
                icon: effect.icon,
                isSelected: selectedEffect == effect,
                onPressed: () async {
                  if (hasEffectPreview && selectedEffect == effect) {
                    widget.appProvider.cancelEffectPreview();
                    return;
                  }
                  await widget.appProvider.startEffectPreview(effect);
                },
              ),
          ],
        ),
        if (hasEffectPreview) const AppDivider(),
        if (hasEffectPreview)
          EffectIntensityControls(
            key: ValueKey<SelectionEffect?>(selectedEffect),
            appProvider: widget.appProvider,
            l10n: widget.l10n,
            sliderKey: Keys.effectIntensitySlider,
            applyButtonKey: Keys.effectIntensityPanelApplyButton,
            cancelButtonKey: Keys.effectIntensityCancelButton,
          ),
      ],
    );
  }
}

/// Builds a shared picker button used across the tools panel grids.
Widget _buildActionPicker({
  final Key? key,
  required final bool minimal,
  required final String name,
  required final AppIcon icon,
  final bool isSelected = false,
  final Color? color,
  required final VoidCallback onPressed,
}) {
  return AppButtonIcon(
    key: key,
    icon: icon,
    isSelected: isSelected,
    color: color,
    onPressed: onPressed,
    tooltip: name,
    constraints: minimal ? const BoxConstraints() : null,
    padding: EdgeInsets.all(minimal ? AppSpacing.thin : AppSpacing.small),
  );
}
