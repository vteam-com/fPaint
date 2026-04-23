import 'package:flutter/material.dart';
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
import 'package:fpaint/widgets/truncated_text.dart';

const String _labelHidden = 'Hidden';
const String _labelOpacity = 'Opacity: ';
const String _labelBlend = 'Blend: ';
const String _dialogLayerNameTitle = 'Layer Name';
const String _dialogCancel = 'Cancel';
const String _dialogApply = 'Apply';
const String _tooltipAddLayerAbove = 'Add a layer above';
const String _tooltipDeleteLayer = 'Delete this layer';
const String _tooltipMergeBelow = 'Merge to below layer';
const String _tooltipBlendMode = 'Blend Mode';
const String _labelBackgroundColor = 'Background Color';
const String _tooltipHideShowLayer = 'Hide/Show this layer';
const String _menuActionRename = 'rename';
const String _menuActionAdd = 'add';
const String _menuActionDelete = 'delete';
const String _menuActionMerge = 'merge';
const String _menuActionBlend = 'blend';
const String _menuActionVisibility = 'visibility';
const String _menuActionAllHide = 'allHide';
const String _menuActionAllShow = 'allShow';
const String _menuLabelRenameLayer = 'Rename layer';
const String _menuLabelChangeBlendMode = 'Change Blend Mode';
const String _menuLabelHideAllOtherLayers = 'Hide all other layers';
const String _menuLabelShowAllLayers = 'Show all layers';
const String _menuLabelHideLayer = 'Hide layer';
const String _menuLabelShowLayer = 'Show layer';
const String _undoActionAddLayer = 'Add Layer';

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
        color: layer.isVisible ? null : Colors.grey.shade600,
        border: Border.all(
          color: layer.isSelected ? Colors.blue : Colors.grey.shade700,
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
    final List<String> texts = <String>[
      '[${layer.id}]',
      layer.name,
      if (!layer.isVisible) _labelHidden,
      '$_labelOpacity${layer.opacity.toStringAsFixed(0)}',
      '$_labelBlend${blendModeToText(layer.blendMode, AppLocalizations.of(context))}',
    ];
    return texts.join('\n');
  }

  /// Renames the layer.
  Future<void> renameLayer() async {
    final TextEditingController controller = TextEditingController(text: layer.name);

    final String? newName = await showDialog<String>(
      context: context,
      builder: (final BuildContext dialogContext) => AlertDialog(
        title: const Text(_dialogLayerNameTitle),
        content: TextField(
          key: Keys.layerRenameTextField,
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: _dialogLayerNameTitle),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(_dialogCancel),
          ),
          TextButton(
            key: Keys.layerRenameApplyButton,
            onPressed: () {
              Navigator.pop(dialogContext, controller.text);
              LayersProvider.of(dialogContext).update();
            },
            child: const Text(_dialogApply),
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

    return Tooltip(
      margin: const EdgeInsets.only(left: AppSpacing.huge),
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
    return Wrap(
      alignment: WrapAlignment.center,
      children: <Widget>[
        IconButton(
          key: Keys.layerAddAboveButton,
          tooltip: _tooltipAddLayerAbove,
          icon: const AppSvgIcon(icon: AppIcon.playlistAdd),
          onPressed: () => _onAddLayer(layers),
        ),
        if (allowRemoveLayer)
          IconButton(
            tooltip: _tooltipDeleteLayer,
            icon: const AppSvgIcon(icon: AppIcon.playlistRemove),
            onPressed: allowRemoveLayer ? () => layers.remove(layer) : null,
          ),
        if (allowRemoveLayer)
          IconButton(
            tooltip: _tooltipMergeBelow,
            icon: const AppSvgIcon(icon: AppIcon.layers),
            onPressed: layer == layers.list.last
                ? null
                : () => _onMergeLayer(
                    layers,
                    layers.selectedLayerIndex,
                    layers.selectedLayerIndex + 1,
                  ),
          ),
        if (allowRemoveLayer)
          IconButton(
            tooltip: '$_tooltipBlendMode\n"${blendModeToText(layer.blendMode, AppLocalizations.of(context))}"',
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
              color: this.layer.backgroundColor ?? Colors.transparent,
              onPressed: () {
                showColorPicker(
                  context: context,
                  title: _labelBackgroundColor,
                  color: this.layer.backgroundColor ?? Colors.transparent,
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
    return Row(
      children: <Widget>[
        PopupMenuButton<String>(
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
                color: isSelected ? Colors.blue.shade100 : Colors.grey.shade400,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: _tooltipHideShowLayer,
          icon: AppSvgIcon(
            icon: layer.isVisible ? AppIcon.visibility : AppIcon.visibilityOff,
            color: layer.isVisible ? Colors.blue : AppColors.layerHiddenWarning,
          ),
          onPressed: () => layers.layersToggleVisibility(layer),
        ),
      ],
    );
  }

  /// Builds the popup menu items for the layer selector.
  List<PopupMenuItem<String>> _buildPopupMenuItems() {
    return <PopupMenuItem<String>>[
      const PopupMenuItem<String>(
        value: _menuActionRename,
        enabled: true,
        child: Row(
          children: <Widget>[
            AppSvgIcon(icon: AppIcon.edit),
            SizedBox(width: AppSpacing.sm),
            Text(_menuLabelRenameLayer),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: _menuActionAdd,
        enabled: true,
        child: Row(
          children: <Widget>[
            AppSvgIcon(icon: AppIcon.playlistAdd),
            SizedBox(width: AppSpacing.sm),
            Text(_tooltipAddLayerAbove),
          ],
        ),
      ),
      if (allowRemoveLayer)
        PopupMenuItem<String>(
          value: _menuActionDelete,
          enabled: allowRemoveLayer,
          child: const Row(
            children: <Widget>[
              AppSvgIcon(icon: AppIcon.playlistRemove),
              SizedBox(width: AppSpacing.sm),
              Text(_tooltipDeleteLayer),
            ],
          ),
        ),
      if (allowRemoveLayer)
        PopupMenuItem<String>(
          value: _menuActionMerge,
          enabled: allowRemoveLayer,
          child: const Row(
            children: <Widget>[
              AppSvgIcon(icon: AppIcon.layers),
              SizedBox(width: AppSpacing.sm),
              Text(_tooltipMergeBelow),
            ],
          ),
        ),
      if (allowRemoveLayer)
        const PopupMenuItem<String>(
          value: _menuActionBlend,
          enabled: true,
          child: Row(
            children: <Widget>[
              AppSvgIcon(icon: AppIcon.blender),
              SizedBox(width: AppSpacing.sm),
              Text(_menuLabelChangeBlendMode),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: _menuActionVisibility,
        enabled: true,
        child: Row(
          children: <Widget>[
            AppSvgIcon(
              icon: layer.isVisible ? AppIcon.visibility : AppIcon.visibilityOff,
              color: layer.isVisible ? Colors.blue : AppColors.layerHiddenWarning,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(layer.isVisible ? _menuLabelHideLayer : _menuLabelShowLayer),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: _menuActionAllHide,
        enabled: true,
        child: Row(
          children: <Widget>[
            AppSvgIcon(icon: AppIcon.visibilityOff),
            SizedBox(width: AppSpacing.sm),
            Text(_menuLabelHideAllOtherLayers),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: _menuActionAllShow,
        enabled: true,
        child: Row(
          children: <Widget>[
            AppSvgIcon(icon: AppIcon.visibility),
            SizedBox(width: AppSpacing.sm),
            Text(_menuLabelShowAllLayers),
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
        showMenu(
          context: context,
          position: const RelativeRect.fromLTRB(0, 0, 0, 0),
          items: _buildPopupMenuItems(),
          elevation: AppSpacing.sm,
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
          if (minimal && !layer.isVisible) const AppSvgIcon(icon: AppIcon.visibilityOff, color: Colors.red),
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
    final UndoProvider undoProvider = UndoProvider();

    final int currentIndex = layers.selectedLayerIndex;

    undoProvider.executeAction(
      name: _undoActionAddLayer,
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
