import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/hatch_marks.dart';
import 'package:fpaint/models/hatch_pattern.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/tools/hatch_tool_option.dart';
import 'package:fpaint/panels/tools/tool_family_rail.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/brush_intensity_picker.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';
import 'package:fpaint/widgets/brush_style_picker.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/gradient_color_list_editor.dart';
import 'package:fpaint/widgets/halftone_size_picker.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/picker_slider_tool_option.dart';
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
  Widget build(BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ToolFamilyRail(
            minimal: minimal,
            gestureParams: ListenableBuilder(
              listenable: appProvider.toolOptionsRepaintListenable,
              builder: (BuildContext _, Widget? _) {
                final ToolKind selectedTool = appProvider.selectedTool;

                return AnimatedSwitcher(
                  duration: AppDefaults.toolPanelRevealAnimationDuration,
                  reverseDuration: AppDefaults.toolPanelRevealAnimationDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<ToolKind>(selectedTool),
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.medium),
                      child: Wrap(
                        runSpacing: minimal ? AppSpacing.small : AppSpacing.thin,
                        alignment: WrapAlignment.center,
                        children: getWidgetForSelectedTool(
                          context: context,
                          appProvider: appProvider,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Top colors palette: pinned at the bottom, after the Elements
          // section, for every tool that supports it.
          ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[
              appProvider.selectedActionRepaintListenable,
              appProvider.toolOptionsRepaintListenable,
            ]),
            builder: (BuildContext context, Widget? _) {
              final ToolKind selectedTool = appProvider.selectedTool;
              final bool showTopColors =
                  appProvider.effectBrushModel.effect == null &&
                  selectedTool != ToolKind.text &&
                  selectedTool.isSupported(ActionOptions.topColors);
              if (!showTopColors) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(left: AppSpacing.medium),
                child: buildToolOptionTopColors(
                  LayersProvider.of(context),
                  appProvider,
                  minimal,
                  context.l10n,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Adds a tool option for brush or fill color.
  void addToolOptionColor(
    List<Widget> widgets,
    AppProvider appProvider,
    BuildContext context,
    bool isBrush,
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
      onColorChanged: (Color selectedColor) {
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
    BuildContext context,
    AppProvider appProvider,
  ) {
    final AppLocalizations l10n = context.l10n;

    return PickerSliderToolOption(
      compact: minimal,
      name: l10n.colorTolerance,
      icon: AppIcon.support,
      onOpenPicker: () {
        showTolerancePicker(context, appProvider.tolerance, (int newValue) {
          appProvider.tolerance = newValue;
        });
      },
      inlineControl: TolerancePicker(
        title: l10n.tolerance,
        value: appProvider.tolerance,
        onChanged: (int value) {
          appProvider.tolerance = value;
        },
      ),
    );
  }

  /// Builds the tool option for top colors.
  Widget buildToolOptionTopColors(
    LayersProvider layers,
    AppProvider appProvider,
    bool minimal,
    AppLocalizations l10n,
  ) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[layers.topColorsListenable, layers.recentColors]),
      builder: (BuildContext _, Widget? _) {
        final List<ColorUsage> paletteColors = layers.recentColors.prioritizeTopColors(layers.topColors);
        return _CollapsibleTopColors(
          compact: minimal,
          name: l10n.topColors(paletteColors.length),
          child: TopColors(
            colorUsages: paletteColors,
            onRefresh: layers.evaluateTopColor,
            onColorPicked: appProvider.applyPaletteColor,
            minimal: minimal,
            showHeader: false,
            autoRefreshOnIdle: true,
            refreshRevision: layers.topColorsRefreshRevision,
            sortColors: false,
          ),
        );
      },
    );
  }

  /// Returns a list of widgets representing the attributes for the selected tool.
  List<Widget> getWidgetForSelectedTool({
    required BuildContext context,
    required AppProvider appProvider,
  }) {
    final List<Widget> widgets = <Widget>[];
    final AppLocalizations l10n = context.l10n;
    final ToolKind selectedTool = appProvider.selectedTool;

    switch (selectedTool) {
      case ToolKind.fill:
        widgets.add(
          ToolAttributeWidget(
            compact: minimal,
            name: l10n.toolFill,
            childRight: Wrap(
              alignment: WrapAlignment.center,
              children: <Widget>[
                //
                // Fill Solid
                //
                _buildActionPicker(
                  key: Keys.toolFillModeSolid,
                  minimal: minimal,
                  name: l10n.toolSolid,
                  icon: AppIcon.fillSolid,
                  isSelected: appProvider.fillModel.mode == FillMode.solid,
                  onPressed: () {
                    appProvider.setFillMode(FillMode.solid);
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
                    appProvider.setFillMode(FillMode.linear);
                    appProvider.updateGradientPreview();
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
                    appProvider.setFillMode(FillMode.radial);
                    appProvider.updateGradientPreview();
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
          _addFillHatchOption(widgets, appProvider, context);
        } else {
          _addGradientColorEditor(widgets, appProvider, context);
          _addHalftoneSlider(widgets, appProvider, context);
        }
        widgets.add(addToolOptionTolerance(context, appProvider));
        break;

      case ToolKind.text:
        widgets.add(
          const TextAttributesWidget(
            minimal: false,
          ),
        );
        break;
      case ToolKind.selector:
        // Selection tooling lives on the canvas (sub-toolbar + bottom sheets),
        // not in the side panel — see shell_selection_sub_toolbar.dart.
        break;

      default:
        final String title = selectedTool == ToolKind.pencil ? l10n.pencilSize : l10n.brushSize;
        final BrushSizeRange sizeRange = selectedTool.brushSizeRange();

        // Brush Size
        if (selectedTool.isSupported(ActionOptions.brushSize)) {
          widgets.add(
            PickerSliderToolOption(
              key: Keys.toolBrushSizeTool,
              compact: minimal,
              name: title,
              buttonKey: Keys.toolBrushSizeButton,
              icon: AppIcon.lineWeight,
              onOpenPicker: () {
                showBrushSizePicker(
                  context: context,
                  title: title,
                  titleIcon: const AppSvgIcon(icon: AppIcon.lineWeight),
                  value: appProvider.brushSize,
                  min: sizeRange.min,
                  max: sizeRange.max,
                  onChanged: (double newValue) {
                    appProvider.brushSize = newValue;
                  },
                );
              },
              inlineControl: BrushSizePicker(
                key: Keys.toolBrushSizeSlider,
                title: title,
                value: appProvider.brushSize,
                min: sizeRange.min,
                max: sizeRange.max,
                onChanged: (double value) {
                  appProvider.brushSize = value;
                },
              ),
            ),
          );
        }

        if (selectedTool.isSupported(ActionOptions.brushIntensity)) {
          widgets.add(
            PickerSliderToolOption(
              key: Keys.toolBrushIntensityTool,
              compact: minimal,
              name: l10n.effectIntensity,
              buttonKey: Keys.toolBrushIntensityButton,
              icon: selectedTool.icon,
              onOpenPicker: () {
                showBrushIntensityPicker(
                  context: context,
                  title: l10n.effectIntensity,
                  titleIcon: AppSvgIcon(icon: selectedTool.icon),
                  value: appProvider.brushIntensity,
                  onChanged: (double newValue) {
                    appProvider.brushIntensity = newValue;
                  },
                );
              },
              inlineControl: AppSlider(
                key: Keys.toolBrushIntensitySlider,
                value: appProvider.brushIntensity,
                min: AppEffects.minIntensity,
                max: AppEffects.maxIntensity,
                divisions: AppLimits.sliderDivisions,
                valueLabel: formatFractionPercent(l10n, appProvider.brushIntensity),
                onChanged: (double value) {
                  appProvider.brushIntensity = value;
                },
              ),
            ),
          );
        }

        // Brush Style
        if (selectedTool.isSupported(ActionOptions.brushStyle)) {
          widgets.add(
            PickerSliderToolOption(
              compact: minimal,
              name: l10n.brushStyle,
              icon: AppIcon.lineStyle,
              onOpenPicker: () {
                showBrushStylePicker(
                  context,
                  appProvider.brushStyle,
                  (BrushStyle selectedBrushStyle) => appProvider.brushStyle = selectedBrushStyle,
                );
              },
              inlineControl: brushStyleDropDown(
                context,
                appProvider.brushStyle,
                (BrushStyle selectedBrushStyle) => appProvider.brushStyle = selectedBrushStyle,
              ),
            ),
          );

          // Hatch geometry, only while a hatch style is the brush style.
          if (appProvider.brushStyle.isHatch) {
            widgets.add(
              buildHatchToolOption(
                context: context,
                compact: minimal,
                pattern: appProvider.hatchPattern.copyWith(crossed: appProvider.brushStyle == BrushStyle.crossHatch),
                onChanged: (HatchPattern next) => _applyBrushHatch(appProvider, next),
                buttonKey: Keys.toolBrushHatchButton,
                sliderKey: Keys.toolBrushHatchSlider,
              ),
            );
          }

          // Tapered-mark geometry, only for the hatch marks style.
          if (appProvider.brushStyle == BrushStyle.hatchMarks) {
            widgets.add(
              buildHatchMarksToolOption(
                context: context,
                compact: minimal,
                marks: appProvider.hatchMarks,
                onChanged: (HatchMarks next) => appProvider.hatchMarks = next,
                buttonKey: Keys.toolBrushHatchMarksButton,
                sliderKey: Keys.toolBrushHatchMarksSlider,
              ),
            );
          }
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
    }

    return widgets;
  }

  /// Adds the toggleable hatch pattern row for solid flood fills.
  void _addFillHatchOption(
    List<Widget> widgets,
    AppProvider appProvider,
    BuildContext context,
  ) {
    final FillModel fillModel = appProvider.fillModel;
    widgets.add(
      buildHatchToolOption(
        context: context,
        compact: minimal,
        pattern: appProvider.hatchPattern.copyWith(crossed: fillModel.hatchCrossed),
        onChanged: (HatchPattern next) {
          appProvider.hatchPattern = next;
          appProvider.setFillHatchCrossed(next.crossed);
          appProvider.updateGradientPreview();
        },
        sliderKey: Keys.toolFillHatchSlider,
        enabled: fillModel.hatchEnabled,
        onEnabledChanged: (bool value) {
          appProvider.setFillHatchEnabled(value);
          appProvider.updateGradientPreview();
        },
        enabledToggleKey: Keys.toolFillHatchToggle,
      ),
    );
  }

  /// Adds the gradient color list editor for linear/radial fill modes.
  void _addGradientColorEditor(
    List<Widget> widgets,
    AppProvider appProvider,
    BuildContext context,
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
                    onSelectedColor: (Color picked) {
                      appProvider.fillModel.gradientStopColors[0] = picked;
                      if (appProvider.fillModel.gradientPoints.isNotEmpty) {
                        appProvider.fillModel.gradientPoints.first.color = picked;
                      }
                      appProvider.updateGradientPreview();
                    },
                  );
                },
              )
            : null,
        childRight: minimal
            ? null
            : GradientColorListEditor(
                fillModel: appProvider.fillModel,
                onChanged: appProvider.updateGradientPreview,
              ),
      ),
    );
  }

  /// Adds the halftone size slider for flood fills.
  void _addHalftoneSlider(
    List<Widget> widgets,
    AppProvider appProvider,
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    final bool halftoneEnabled = appProvider.fillModel.halftoneEnabled;
    final int halftonePercent = appProvider.fillModel.halftoneMaxDotSizePercent;

    void updateHalftonePercent(int value) {
      appProvider.setFillHalftoneMaxDotSizePercent(value);
      appProvider.updateGradientPreview();
    }

    void updateHalftoneEnabled(bool value) {
      appProvider.setFillHalftoneEnabled(value);
      appProvider.updateGradientPreview();
    }

    widgets.add(
      PickerSliderToolOption(
        compact: minimal,
        name: l10n.toolHalftone,
        enabled: halftoneEnabled,
        onEnabledChanged: updateHalftoneEnabled,
        enabledToggleKey: Keys.toolFillHalftoneToggle,
        icon: AppIcon.halftone,
        isSelected: halftoneEnabled,
        tooltip: l10n.toolHalftone,
        onOpenPicker: () {
          showHalftoneSizePicker(
            context: context,
            value: halftonePercent,
            enabled: halftoneEnabled,
            onChanged: updateHalftonePercent,
            onEnabledChanged: updateHalftoneEnabled,
          );
        },
        inlineControl: AppSlider(
          key: Keys.toolFillHalftoneSlider,
          valueLabel: l10n.percentageValue(halftonePercent),
          value: halftonePercent.toDouble(),
          min: AppMath.zero.toDouble(),
          max: AppLimits.percentMax.toDouble(),
          divisions: AppLimits.sliderDivisions,
          onChanged: halftoneEnabled ? (double value) => updateHalftonePercent(value.toInt()) : null,
        ),
      ),
    );
  }

  /// Adds a color-related tool option row with preview, picker, and selector.
  void _addToolOptionColor({
    required List<Widget> widgets,
    required BuildContext context,
    required String name,
    required Key previewKey,
    required Color color,
    required bool isPickFromCanvasActive,
    required ValueChanged<Color> onColorChanged,
    required VoidCallback onPickFromCanvas,
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

  /// Applies an edited hatch pattern to the brush: the geometry goes to the
  /// shared setting, the cross switch picks between the two hatch styles.
  void _applyBrushHatch(AppProvider appProvider, HatchPattern next) {
    appProvider.hatchPattern = next;
    final BrushStyle style = next.crossed ? BrushStyle.crossHatch : BrushStyle.hatch;
    if (appProvider.brushStyle != style) {
      appProvider.brushStyle = style;
    }
  }
}

/// Wraps the top colors grid in a collapsible tool attribute, collapsed by default.
class _CollapsibleTopColors extends StatefulWidget {
  const _CollapsibleTopColors({
    required this.name,
    required this.compact,
    required this.child,
  });

  /// The top colors grid revealed when expanded.
  final Widget child;

  /// Whether the tool panel is in minimal mode.
  final bool compact;

  /// The label shown on the expand/collapse toggle.
  final String name;

  @override
  State<_CollapsibleTopColors> createState() => _CollapsibleTopColorsState();
}

class _CollapsibleTopColorsState extends State<_CollapsibleTopColors> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ToolAttributeWidget(
      compact: widget.compact,
      name: widget.name,
      enabled: _expanded,
      enabledToggleKey: Keys.toolPanelTopColorsToggle,
      onEnabledChanged: (bool value) => setState(() => _expanded = value),
      childRight: widget.child,
    );
  }
}

/// Builds a shared picker button used across the tools panel grids.
Widget _buildActionPicker({
  Key? key,
  required bool minimal,
  required String name,
  required AppIcon icon,
  bool isSelected = false,
  Color? color,
  bool useSourceColors = false,
  required VoidCallback onPressed,
}) {
  return AppButtonIcon.toolOption(
    key: key,
    icon: icon,
    compact: minimal,
    isSelected: isSelected,
    color: color,
    useSourceColors: useSourceColors,
    onPressed: onPressed,
    tooltip: name,
  );
}
