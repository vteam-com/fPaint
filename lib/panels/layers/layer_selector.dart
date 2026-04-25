import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/layers/blend_mode.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/container_slider.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';
import 'package:fpaint/widgets/truncated_text.dart';

const String _menuActionRename = 'rename';
const String _menuActionAdd = 'add';
const String _menuActionDelete = 'delete';
const String _menuActionMerge = 'merge';
const String _menuActionBlend = 'blend';
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
      margin: EdgeInsets.all(minimal ? AppSpacing.thin : AppSpacing.xs),
      padding: EdgeInsets.all(minimal ? AppSpacing.thin : AppSpacing.sm),
      decoration: BoxDecoration(
        color: layer.isVisible ? null : AppPalette.grey600,
        border: Border.all(
          color: layer.isSelected ? AppPalette.blue : AppPalette.grey700,
          width: AppStroke.emphasis,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
        title: Text(l10n.layerNameTitle),
        content: AppTextField(
          key: Keys.layerRenameTextField,
          controller: controller,
          autofocus: true,
          hintText: l10n.layerNameTitle,
        ),
        actions: <Widget>[
          AppTextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          AppTextButton(
            key: Keys.layerRenameApplyButton,
            onPressed: () {
              Navigator.pop(dialogContext, controller.text);
              LayersProvider.of(dialogContext).update();
            },
            child: Text(l10n.apply),
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
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
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
          TruncatedTextWidget(text: layer.name, maxLength: AppSpacing.md.toInt()),
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
        AppIconButton(
          key: Keys.layerAddAboveButton,
          tooltip: l10n.layerAddAbove,
          icon: const AppSvgIcon(icon: AppIcon.playlistAdd),
          onPressed: () => _onAddLayer(layers),
        ),
        if (allowRemoveLayer)
          AppIconButton(
            tooltip: l10n.layerDelete,
            icon: const AppSvgIcon(icon: AppIcon.playlistRemove),
            onPressed: () => layers.remove(layer),
          ),
        if (allowRemoveLayer)
          AppIconButton(
            tooltip: l10n.layerMergeBelow,
            icon: const AppSvgIcon(icon: AppIcon.layers),
            onPressed: layer == layers.list.last
                ? () {}
                : () => _onMergeLayer(
                    layers,
                    layers.selectedLayerIndex,
                    layers.selectedLayerIndex + 1,
                  ),
          ),
        if (allowRemoveLayer)
          AppIconButton(
            tooltip: '${l10n.layerBlendMode}\n"${blendModeToText(layer.blendMode, AppLocalizations.of(context))}"',
            icon: const AppSvgIcon(icon: AppIcon.blender),
            onPressed: () async {
              layer.blendMode = await showBlendModeMenu(
                context: context,
                selectedBlendMode: layer.blendMode,
              );
            },
          ),
        if (this.layer.backgroundColor != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.huge),
            child: ColorPreview(
              color: this.layer.backgroundColor ?? AppPalette.transparent,
              onPressed: () {
                showColorPicker(
                  context: context,
                  title: l10n.layerBackgroundColor,
                  color: this.layer.backgroundColor ?? AppPalette.transparent,
                  onSelectedColor: (final Color color) {
                    this.layer.backgroundColor = color;
                    layer.clearCache();
                    layers.update();
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  /// Builds the layer name widget.
  Widget _buildLayerName(final LayersProvider layers) {
    final AppLocalizations l10n = context.l10n;
    return Row(
      children: <Widget>[
        AppPopupMenuButton<String>(
          icon: const AppSvgIcon(icon: AppIcon.moreVert),
          itemBuilder: (final BuildContext _) => _buildPopupMenuItems(),
          onSelected: (final String value) => _handlePopupMenuSelection(value, layers),
        ),
        if (layer.parentGroupName.isNotEmpty)
          Opacity(
            opacity: AppVisual.half,
            child: Text('${layer.parentGroupName}.'),
          ),
        Expanded(
          child: GestureDetector(
            onLongPress: () async {
              await renameLayer();
            },
            child: Text(
              layer.name,
              style: TextStyle(
                fontSize: AppFontSize.title * AppVisual.titleScale,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppPalette.blueShade100 : AppPalette.grey400,
              ),
            ),
          ),
        ),
        AppIconButton(
          tooltip: l10n.layerToggleVisibility,
          icon: AppSvgIcon(
            icon: layer.isVisible ? AppIcon.visibility : AppIcon.visibilityOff,
            color: layer.isVisible ? AppPalette.blue : AppColors.layerHiddenWarning,
          ),
          onPressed: () => layers.layersToggleVisibility(layer),
        ),
      ],
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
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.layerRename),
          ],
        ),
      ),
      AppPopupMenuItem<String>(
        value: _menuActionAdd,
        child: Row(
          children: <Widget>[
            const AppSvgIcon(icon: AppIcon.playlistAdd),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.layerAddAbove),
          ],
        ),
      ),
      if (allowRemoveLayer)
        AppPopupMenuItem<String>(
          value: _menuActionDelete,
          child: Row(
            children: <Widget>[
              const AppSvgIcon(icon: AppIcon.playlistRemove),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.layerDelete),
            ],
          ),
        ),
      if (allowRemoveLayer)
        AppPopupMenuItem<String>(
          value: _menuActionMerge,
          child: Row(
            children: <Widget>[
              const AppSvgIcon(icon: AppIcon.layers),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.layerMergeBelow),
            ],
          ),
        ),
      if (allowRemoveLayer)
        AppPopupMenuItem<String>(
          value: _menuActionBlend,
          child: Row(
            children: <Widget>[
              const AppSvgIcon(icon: AppIcon.blender),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.layerChangeBlendMode),
            ],
          ),
        ),
      AppPopupMenuItem<String>(
        value: _menuActionVisibility,
        child: Row(
          children: <Widget>[
            AppSvgIcon(
              icon: layer.isVisible ? AppIcon.visibility : AppIcon.visibilityOff,
              color: layer.isVisible ? AppPalette.blue : AppColors.layerHiddenWarning,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(layer.isVisible ? l10n.layerHide : l10n.layerShow),
          ],
        ),
      ),
      AppPopupMenuItem<String>(
        value: _menuActionAllHide,
        child: Row(
          children: <Widget>[
            const AppSvgIcon(icon: AppIcon.visibilityOff),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.layerHideAllOthers),
          ],
        ),
      ),
      AppPopupMenuItem<String>(
        value: _menuActionAllShow,
        child: Row(
          children: <Widget>[
            const AppSvgIcon(icon: AppIcon.visibility),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.layerShowAll),
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
          if (minimal && !layer.isVisible) const AppSvgIcon(icon: AppIcon.visibilityOff, color: AppPalette.red),
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
    final UndoProvider undoProvider = UndoProvider();

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
}
