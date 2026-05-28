import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/layers/blend_mode.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/container_slider.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/truncated_text.dart';

const String _menuActionRename = 'rename';
const String _menuActionModify = 'modify';
const String _menuActionAdd = 'add';
const String _menuActionDelete = 'delete';
const String _menuActionMerge = 'merge';
const String _menuActionBlend = 'blend';
const String _menuActionLock = 'lock';
const String _menuActionVisibility = 'visibility';
const String _menuActionAllHide = 'allHide';
const String _menuActionAllShow = 'allShow';

/// A widget that displays a layer in the layer selector panel.
class LayerSelector extends StatelessWidget {
  const LayerSelector({
    super.key,
    required this.context,
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

  /// Whether to display the layer in minimal mode.
  final bool minimal;
  @override
  Widget build(final BuildContext context) {
    final LayersProvider layers = LayersProvider.of(context);
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
              context,
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
      builder: (final BuildContext dialogContext) => AppDialog(
        title: l10n.layerNameTitle,
        content: AppTextField(
          key: Keys.layerRenameTextField,
          controller: controller,
          autofocus: true,
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
              LayersProvider.of(dialogContext).update();
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

  /// Builds the layer selector for a large surface.
  Widget _buildForLargeSurface(
    final BuildContext context,
    final LayersProvider layers,
    final LayerProvider layer,
    final bool allowRemoveLayer,
  ) {
    return LayoutBuilder(
      builder: (final BuildContext _, final BoxConstraints constraints) {
        final bool hasBoundedWidth = constraints.hasBoundedWidth;
        return Row(
          mainAxisSize: hasBoundedWidth ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            if (hasBoundedWidth)
              Expanded(
                child: Column(
                  children: <Widget>[
                    _buildLayerName(layers),
                    if (isSelected) _buildLayerControls(context, layers, layer, allowRemoveLayer),
                  ],
                ),
              )
            else
              Flexible(
                fit: FlexFit.loose,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
    final BuildContext context,
    final LayerProvider layer,
  ) {
    final LayersProvider layers = LayersProvider.of(context);

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
    final BuildContext context,
    final LayersProvider layers,
    final LayerProvider layer,
    final bool allowRemoveLayer,
  ) {
    final AppLocalizations l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      children: <Widget>[
        AppButtonIcon(
          key: Keys.layerAddAboveButton,
          tooltip: l10n.layerAddAbove,
          icon: AppIcon.playlistAdd,
          onPressed: () => _onAddLayer(layers),
        ),
        if (allowRemoveLayer)
          AppButtonIcon(
            tooltip: l10n.layerDelete,
            icon: AppIcon.playlistRemove,
            onPressed: () => layers.remove(layer),
          ),
        if (allowRemoveLayer)
          AppButtonIcon(
            tooltip: l10n.layerMergeBelow,
            icon: AppIcon.layers,
            onPressed: layer == layers.list.last
                ? () {}
                : () => _onMergeLayer(
                    layers,
                    layers.selectedLayerIndex,
                    layers.selectedLayerIndex + 1,
                  ),
          ),
        if (allowRemoveLayer)
          AppButtonIcon(
            tooltip: '${l10n.layerBlendMode}\n"${blendModeToText(layer.blendMode, AppLocalizations.of(context))}"',
            icon: AppIcon.blender,
            onPressed: () async {
              layer.blendMode = await showBlendModeMenu(
                context: context,
                selectedBlendMode: layer.blendMode,
              );
            },
          ),
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
                  onSelectedColor: (final Color color) {
                    this.layer.backgroundColor = color;
                    layer.clearCache();
                    layers.update();
                  },
                );
              },
            ),
          ),
        AppButtonIcon(
          key: Keys.layerModifyButton,
          tooltip: l10n.layerModify,
          icon: AppIcon.transform,
          onPressed: () => _onModifyLayer(layers),
        ),
      ],
    );
  }

  /// Builds the layer name widget.
  Widget _buildLayerName(final LayersProvider layers) {
    final AppLocalizations l10n = context.l10n;
    return LayoutBuilder(
      builder: (final BuildContext _, final BoxConstraints constraints) {
        final bool hasBoundedWidth = constraints.hasBoundedWidth;
        return Row(
          mainAxisSize: hasBoundedWidth ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            if (layer.parentGroupName.isNotEmpty)
              Opacity(
                opacity: AppVisual.half,
                child: AppText('${layer.parentGroupName}.'),
              ),
            if (hasBoundedWidth)
              Expanded(
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
              )
            else
              Flexible(
                fit: FlexFit.loose,
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
            AppButtonIcon(
              key: Keys.layerToggleLockButton,
              tooltip: layer.isLocked ? l10n.layerUnlockEdits : l10n.layerLockEdits,
              icon: layer.isLocked ? AppIcon.lock : AppIcon.lockOpen,
              color: layer.isLocked ? AppColors.layerHiddenWarning : AppColors.grey400,
              onPressed: () => layers.layersToggleLock(layer),
            ),
            AppButtonIcon(
              tooltip: l10n.layerToggleVisibility,
              icon: layer.isVisible ? AppIcon.visibility : AppIcon.visibilityOff,
              color: layer.isVisible ? AppColors.primary : AppColors.layerHiddenWarning,
              onPressed: () => layers.layersToggleVisibility(layer),
            ),
            AppPopupMenuButton<String>(
              itemBuilder: (final BuildContext _) => _buildPopupMenuItems(),
              onSelected: (final String value) => _handlePopupMenuSelection(value, layers),
              child: const AppSvgIcon(icon: AppIcon.moreVert),
            ),
          ],
        );
      },
    );
  }

  /// Builds the popup menu items for the layer selector.
  List<AppPopupMenuItem<String>> _buildPopupMenuItems() {
    final AppLocalizations l10n = context.l10n;
    return <AppPopupMenuItem<String>>[
      AppPopupMenuItem<String>(
        value: _menuActionRename,
        child: Row(
          children: <Widget>[
            const AppSvgIcon(icon: AppIcon.edit),
            const SizedBox(width: AppSpacing.small),
            AppText(l10n.layerRename),
          ],
        ),
      ),
      AppPopupMenuItem<String>(
        value: _menuActionModify,
        child: Row(
          children: <Widget>[
            const AppSvgIcon(icon: AppIcon.transform),
            const SizedBox(width: AppSpacing.small),
            AppText(l10n.layerModify),
          ],
        ),
      ),
      AppPopupMenuItem<String>(
        value: _menuActionAdd,
        child: Row(
          children: <Widget>[
            const AppSvgIcon(icon: AppIcon.playlistAdd),
            const SizedBox(width: AppSpacing.small),
            AppText(l10n.layerAddAbove),
          ],
        ),
      ),
      if (allowRemoveLayer)
        AppPopupMenuItem<String>(
          value: _menuActionDelete,
          child: Row(
            children: <Widget>[
              const AppSvgIcon(icon: AppIcon.playlistRemove),
              const SizedBox(width: AppSpacing.small),
              AppText(l10n.layerDelete),
            ],
          ),
        ),
      if (allowRemoveLayer)
        AppPopupMenuItem<String>(
          value: _menuActionMerge,
          child: Row(
            children: <Widget>[
              const AppSvgIcon(icon: AppIcon.layers),
              const SizedBox(width: AppSpacing.small),
              AppText(l10n.layerMergeBelow),
            ],
          ),
        ),
      if (allowRemoveLayer)
        AppPopupMenuItem<String>(
          value: _menuActionBlend,
          child: Row(
            children: <Widget>[
              const AppSvgIcon(icon: AppIcon.blender),
              const SizedBox(width: AppSpacing.small),
              AppText(l10n.layerChangeBlendMode),
            ],
          ),
        ),
      AppPopupMenuItem<String>(
        value: _menuActionLock,
        child: Row(
          children: <Widget>[
            AppSvgIcon(
              icon: layer.isLocked ? AppIcon.lock : AppIcon.lockOpen,
              color: layer.isLocked ? AppColors.layerHiddenWarning : null,
            ),
            const SizedBox(width: AppSpacing.small),
            AppText(layer.isLocked ? l10n.layerUnlockEdits : l10n.layerLockEdits),
          ],
        ),
      ),
      AppPopupMenuItem<String>(
        value: _menuActionVisibility,
        child: Row(
          children: <Widget>[
            AppSvgIcon(
              icon: layer.isVisible ? AppIcon.visibility : AppIcon.visibilityOff,
              color: layer.isVisible ? AppColors.primary : AppColors.layerHiddenWarning,
            ),
            const SizedBox(width: AppSpacing.small),
            AppText(layer.isVisible ? l10n.layerHide : l10n.layerShow),
          ],
        ),
      ),
      AppPopupMenuItem<String>(
        value: _menuActionAllHide,
        child: Row(
          children: <Widget>[
            const AppSvgIcon(icon: AppIcon.visibilityOff),
            const SizedBox(width: AppSpacing.small),
            AppText(l10n.layerHideAllOthers),
          ],
        ),
      ),
      AppPopupMenuItem<String>(
        value: _menuActionAllShow,
        child: Row(
          children: <Widget>[
            const AppSvgIcon(icon: AppIcon.visibility),
            const SizedBox(width: AppSpacing.small),
            AppText(l10n.layerShowAll),
          ],
        ),
      ),
    ];
  }

  /// Builds the thumbnail preview widget.
  Widget _buildThumbnailPreview(
    final LayersProvider layers,
    final LayerProvider layer,
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
        onChanged: (final double value) => layer.opacity = value,
        onChangeEnd: (final double value) {
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
    final LayersProvider layers,
    final LayerProvider layer,
  ) {
    return GestureDetector(
      onLongPress: () {
        showAppMenu<String>(
          context: context,
          position: const RelativeRect.fromLTRB(0, 0, 0, 0),
          items: _buildPopupMenuItems(),
        ).then((final String? value) {
          if (value != null) {
            _handlePopupMenuSelection(value, layers);
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
                  if (layer.isLocked) const AppSvgIcon(icon: AppIcon.lock, color: AppColors.layerHiddenWarning),
                  if (!layer.isVisible) const AppSvgIcon(icon: AppIcon.visibilityOff, color: AppColors.red),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Handles the selection of a popup menu item.
  Future<void> _handlePopupMenuSelection(
    final String value,
    final LayersProvider layers,
  ) async {
    switch (value) {
      case _menuActionRename:
        await renameLayer();
        break;
      case _menuActionModify:
        await _onModifyLayer(layers);
        break;
      case _menuActionAdd:
        _onAddLayer(layers);
        break;
      case _menuActionDelete:
        if (allowRemoveLayer) {
          layers.remove(layer);
        }
        break;
      case _menuActionMerge:
        if (layer != layers.list.last) {
          _onMergeLayer(
            layers,
            layers.selectedLayerIndex,
            layers.selectedLayerIndex + 1,
          );
        }
        break;
      case _menuActionBlend:
        layer.blendMode = await showBlendModeMenu(
          context: context,
          selectedBlendMode: layer.blendMode,
        );
        break;
      case _menuActionLock:
        layers.layersToggleLock(layer);
        break;
      case _menuActionVisibility:
        layers.layersToggleVisibility(layer);
        break;
      case _menuActionAllHide:
        layers.hideShowAllExcept(layer, false);
        layers.update();
        break;
      case _menuActionAllShow:
        layers.hideShowAllExcept(layer, true);
        layers.update();
        break;
    }
  }

  /// Method to insert a new layer above the currently selected one
  void _onAddLayer(final LayersProvider layers) {
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

  /// Method to flatten all layers
  void _onMergeLayer(
    final LayersProvider layers,
    final int indexFrom,
    final int indexTo,
  ) {
    layers.mergeLayers(indexFrom, indexTo);
  }

  /// Floats the current layer into modify mode.
  Future<void> _onModifyLayer(final LayersProvider layers) async {
    final AppProvider appProvider = AppProvider.of(context);
    layers.selectedLayerIndex = layers.getLayerIndex(layer);

    if (appProvider.isSelectedLayerLocked) {
      _showLockedLayerMessage(appProvider);
      return;
    }

    await appProvider.modifySelectedLayer();
  }

  void _showLockedLayerMessage(final AppProvider appProvider) {
    context.showSnackBarMessage(
      context.l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
    );
  }
}
