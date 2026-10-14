import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/layers/blend_mode.dart';
import 'package:fpaint/panels/layers/layer_actions.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/container_slider.dart';
import 'package:fpaint/widgets/locked_layer_guard.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/truncated_text.dart';

/// A widget that displays a layer in the layer selector panel.
class LayerSelector extends StatelessWidget {
  const LayerSelector({
    super.key,
    required this.context,
    required this.layers,
    required this.layer,
    required this.minimal,
    required this.isSelected,
    required this.allowRemoveLayer,
  });

  /// Whether to allow removing the layer.
  final bool allowRemoveLayer;

  /// The build context.
  final BuildContext context;

  /// Whether the layer is selected.
  final bool isSelected;

  /// The layer to display.
  final LayerProvider layer;

  /// The document this layer belongs to. Passed in by the parent (which already
  /// holds it) rather than resolved from context, so the selector still works
  /// when built outside the editor's [InheritedControllerScope] (e.g. in an
  /// overlay/dialog subtree rooted above that scope).
  final LayersProvider layers;

  /// Whether to display the layer in minimal mode.
  final bool minimal;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(minimal ? AppSpacing.thin : AppSpacing.small),
      padding: EdgeInsets.all(minimal ? AppSpacing.thin : AppSpacing.small),
      decoration: BoxDecoration(
        color: layer.isVisible ? null : AppColors.grey600,
        border: Border.all(
          color: layer.isSelected ? AppColors.selected : AppColors.grey700,
          width: AppStroke.emphasis,
        ),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: minimal
          ? _buildForSmallSurface(
              layer,
            )
          : _buildForLargeSurface(
              context,
              layers,
              layer,
              allowRemoveLayer,
            ),
    );
  }

  /// Returns information about the layer.
  String information() {
    final AppLocalizations l10n = context.l10n;
    final List<String> texts = <String>[
      '[${layer.id}]',
      layer.name,
      if (!layer.isVisible) l10n.layerHidden,
      if (layer.isLocked) l10n.layerEditsLocked,
      '${l10n.layerOpacity}${layer.opacity.toStringAsFixed(0)}',
      '${l10n.layerBlend}${blendModeToText(layer.blendMode, AppLocalizations.of(context))}',
    ];
    return texts.join('\n');
  }

  /// Renames the layer.
  Future<void> renameLayer() async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController controller = TextEditingController(text: layer.name);

    final String? newName = await showAppDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AppDialog(
        title: l10n.layerNameTitle,
        content: AppTextField(
          key: Keys.layerRenameTextField,
          controller: controller,
          autofocus: true,
          selectAllOnFocus: true,
          hintText: l10n.layerNameTitle,
        ),
        actions: <Widget>[
          AppRowSecondaryButton(
            onPressed: () => Navigator.pop(dialogContext),
            text: l10n.cancel,
          ),
          AppRowPrimaryButton(
            key: Keys.layerRenameApplyButton,
            onPressed: () {
              Navigator.pop(dialogContext, controller.text);
              layers.update();
            },
            text: l10n.apply,
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) {
      return;
    }
    layer.name = newName;
  }

  /// Builds the inline button for [action], labelled with [tooltip] (the
  /// action's menu label by default) and tinted [defaultColor] when the action
  /// has no state tint.
  Widget _buildActionButton(
    LayerAction action,
    LayersProvider layers, {
    Key? key,
    String? tooltip,
    Color? defaultColor,
  }) {
    return AppButtonIcon(
      key: key,
      tooltip: tooltip ?? action.label(context.l10n, layer),
      icon: action.icon(layer),
      color: action.iconColor(layer) ?? defaultColor,
      onPressed: () => _performAction(action, layers),
    );
  }

  /// Builds the layer selector for a large surface.
  Widget _buildForLargeSurface(
    BuildContext context,
    LayersProvider layers,
    LayerProvider layer,
    bool allowRemoveLayer,
  ) {
    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints constraints) {
        final bool hasBoundedWidth = constraints.hasBoundedWidth;
        return Row(
          mainAxisSize: hasBoundedWidth ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            _flexibleForWidth(
              hasBoundedWidth: hasBoundedWidth,
              child: Column(
                mainAxisSize: hasBoundedWidth ? MainAxisSize.max : MainAxisSize.min,
                children: <Widget>[
                  _buildLayerName(layers),
                  if (isSelected) _buildLayerControls(context, layers, layer, allowRemoveLayer),
                ],
              ),
            ),
            _buildThumbnailPreviewAndVisibility(
              layers,
              layer,
            ),
          ],
        );
      },
    );
  }

  /// Builds the layer selector for a small surface.
  Widget _buildForSmallSurface(
    LayerProvider layer,
  ) {
    return AppTooltip(
      message: information(),
      child: Column(
        children: <Widget>[
          TruncatedTextWidget(text: layer.name, maxLength: AppSpacing.medium.toInt()),
          _buildThumbnailPreviewAndVisibility(
            layers,
            layer,
          ),
        ],
      ),
    );
  }

  /// Builds the layer controls widget.
  Widget _buildLayerControls(
    BuildContext context,
    LayersProvider layers,
    LayerProvider layer,
    bool allowRemoveLayer,
  ) {
    final AppLocalizations l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      children: <Widget>[
        _buildActionButton(LayerAction.addAbove, layers, key: Keys.layerAddAboveButton),
        if (allowRemoveLayer) ...<Widget>[
          _buildActionButton(LayerAction.delete, layers),
          _buildActionButton(LayerAction.mergeBelow, layers),
          _buildActionButton(
            LayerAction.blendMode,
            layers,
            tooltip: '${l10n.layerBlendMode}\n"${blendModeToText(layer.blendMode, AppLocalizations.of(context))}"',
          ),
        ],
        if (this.layer.backgroundColor != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.largest),
            child: ColorPreview(
              color: this.layer.backgroundColor ?? AppColors.transparent,
              onPressed: () {
                showColorPicker(
                  context: context,
                  title: l10n.layerBackgroundColor,
                  color: this.layer.backgroundColor ?? AppColors.transparent,
                  onSelectedColor: (Color color) {
                    this.layer.backgroundColor = color;
                    layer.clearCache();
                    layers.update();
                  },
                );
              },
            ),
          ),
        _buildActionButton(LayerAction.modify, layers, key: Keys.layerModifyButton),
      ],
    );
  }

  /// Builds the layer name widget.
  Widget _buildLayerName(LayersProvider layers) {
    final AppLocalizations l10n = context.l10n;
    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints constraints) {
        final bool hasBoundedWidth = constraints.hasBoundedWidth;
        return Row(
          mainAxisSize: hasBoundedWidth ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            if (layer.parentGroupName.isNotEmpty)
              Opacity(
                opacity: AppVisual.half,
                child: AppText('${layer.parentGroupName}.'),
              ),
            _flexibleForWidth(
              hasBoundedWidth: hasBoundedWidth,
              child: GestureDetector(
                onLongPress: () async {
                  await renameLayer();
                },
                child: AppText(
                  layer.name,
                  variant: AppTextVariant.bodyBold,
                  color: isSelected ? AppColors.blueShade100 : AppColors.grey400,
                ),
              ),
            ),
            _buildActionButton(
              LayerAction.lock,
              layers,
              key: Keys.layerToggleLockButton,
              defaultColor: AppColors.grey400,
            ),
            _buildActionButton(
              LayerAction.visibility,
              layers,
              tooltip: l10n.layerToggleVisibility,
            ),
            AppPopupMenuButton<LayerAction>(
              itemBuilder: (BuildContext _) => _buildPopupMenuItems(),
              onSelected: (LayerAction action) => _performAction(action, layers),
              child: const AppSvgIcon(icon: AppIcon.moreVert),
            ),
          ],
        );
      },
    );
  }

  /// Builds the popup menu items for the layer selector.
  List<AppPopupMenuItem<LayerAction>> _buildPopupMenuItems() {
    final AppLocalizations l10n = context.l10n;
    return <AppPopupMenuItem<LayerAction>>[
      for (final LayerAction action in LayerAction.values)
        if (allowRemoveLayer || !action.requiresRemovableLayer)
          buildMenuItem<LayerAction>(
            value: action,
            text: action.label(l10n, layer),
            icon: action.icon(layer),
            iconColor: action.iconColor(layer),
          ),
    ];
  }

  /// Builds the thumbnail preview widget.
  Widget _buildThumbnailPreview(
    LayersProvider layers,
    LayerProvider layer,
  ) {
    return SizedBox(
      height: AppLayout.layerPreviewSize,
      width: AppLayout.layerPreviewSize,
      child: ContainerSlider(
        key: ValueKey<String>(layer.name + layer.id),
        minValue: 0.0,
        maxValue: 1.0,
        initialValue: layer.opacity,
        onSlideStart: () {
          // appProvider.update();
        },
        onChanged: (double value) => layer.opacity = value,
        onChangeEnd: (double value) {
          layer.opacity = value;
          layer.clearCache();
          layers.update();
        },
        onSlideEnd: () => layers.update(),
        child: LayerThumbnail(layer: layer),
      ),
    );
  }

  /// Builds the thumbnail preview and visibility widget.
  Widget _buildThumbnailPreviewAndVisibility(
    LayersProvider layers,
    LayerProvider layer,
  ) {
    return GestureDetector(
      onLongPress: () {
        showAppMenu<LayerAction>(
          context: context,
          position: const RelativeRect.fromLTRB(0, 0, 0, 0),
          items: _buildPopupMenuItems(),
        ).then((LayerAction? action) {
          if (action != null) {
            _performAction(action, layers);
          }
        });
      },
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          _buildThumbnailPreview(layers, layer),
          if (minimal && (layer.isLocked || !layer.isVisible))
            Positioned(
              top: AppSpacing.thin,
              right: AppSpacing.thin,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final LayerAction badge in <LayerAction>[
                    if (layer.isLocked) LayerAction.lock,
                    if (!layer.isVisible) LayerAction.visibility,
                  ])
                    AppSvgIcon(icon: badge.icon(layer), color: badge.iconColor(layer)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Wraps [child] to fill the row when its width is bounded, or to shrink-wrap
  /// it otherwise (an unbounded row cannot host an [Expanded]).
  Widget _flexibleForWidth({required bool hasBoundedWidth, required Widget child}) {
    return Flexible(
      fit: hasBoundedWidth ? FlexFit.tight : FlexFit.loose,
      child: child,
    );
  }

  /// Method to insert a new layer above the currently selected one
  void _onAddLayer(LayersProvider layers) {
    final AppLocalizations l10n = context.l10n;
    final UndoProvider undoProvider = UndoProvider.of(context);

    final int currentIndex = layers.selectedLayerIndex;

    undoProvider.executeAction(
      name: l10n.layerAdd,
      forward: () {
        // Add
        final LayerProvider newLayer = layers.insertAt(currentIndex);
        // Change selected layer to the new added layer
        layers.selectedLayerIndex = layers.getLayerIndex(newLayer);
      },
      backward: () {
        layers.removeByIndex(currentIndex);
        layers.selectedLayerIndex = currentIndex;
      },
    );
  }

  /// Floats the current layer into modify mode.
  Future<void> _onModifyLayer(LayersProvider layers) async {
    final AppProvider appProvider = AppProvider.of(context);
    layers.selectedLayerIndex = layers.getLayerIndex(layer);

    if (!guardSelectedLayerUnlocked(context, appProvider)) {
      return;
    }

    await appProvider.modifySelectedLayer();
  }

  /// Performs [action] on this layer, from either its button or its menu.
  Future<void> _performAction(
    LayerAction action,
    LayersProvider layers,
  ) async {
    switch (action) {
      case LayerAction.rename:
        await renameLayer();
      case LayerAction.modify:
        await _onModifyLayer(layers);
      case LayerAction.addAbove:
        _onAddLayer(layers);
      case LayerAction.delete:
        if (allowRemoveLayer) {
          layers.remove(layer);
        }
      case LayerAction.mergeBelow:
        if (layer != layers.list.last) {
          layers.mergeLayers(layers.selectedLayerIndex, layers.selectedLayerIndex + 1);
        }
      case LayerAction.blendMode:
        await _pickBlendMode(context, layer);
      case LayerAction.lock:
        layers.layersToggleLock(layer);
      case LayerAction.visibility:
        layers.layersToggleVisibility(layer);
      case LayerAction.hideOthers:
        layers.hideShowAllExcept(layer, false);
        layers.update();
      case LayerAction.showAll:
        layers.hideShowAllExcept(layer, true);
        layers.update();
    }
  }

  /// Opens the blend-mode menu for [targetLayer] and applies the choice.
  ///
  /// Dismissing the menu leaves the current blend mode untouched.
  Future<void> _pickBlendMode(BuildContext menuContext, LayerProvider targetLayer) async {
    final BlendMode? picked = await showBlendModeMenu(
      context: menuContext,
      selectedBlendMode: targetLayer.blendMode,
    );
    if (picked != null) {
      targetLayer.blendMode = picked;
    }
  }
}
