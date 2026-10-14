import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/layer_provider.dart';

/// Actions offered on one layer, from its inline button row and from its
/// popup menu.
///
/// Each action owns its icon, tint and menu label once, so the buttons and
/// the menu always agree on how a layer state (locked, hidden) is shown.
enum LayerAction {
  /// Renames the layer.
  rename,

  /// Floats the layer into modify (transform) mode.
  modify,

  /// Inserts a new layer above.
  addAbove,

  /// Deletes the layer.
  delete,

  /// Merges the layer into the one below.
  mergeBelow,

  /// Picks the layer's blend mode.
  blendMode,

  /// Toggles the layer's edit lock.
  lock,

  /// Toggles the layer's visibility.
  visibility,

  /// Hides every other layer.
  hideOthers,

  /// Shows every layer.
  showAll;

  /// Whether the action removes or combines layers, so it is only offered
  /// while the document allows removing layers.
  bool get requiresRemovableLayer {
    return this == LayerAction.delete || this == LayerAction.mergeBelow || this == LayerAction.blendMode;
  }

  /// Icon of this action for [layer]'s current state.
  AppIcon icon(LayerProvider layer) {
    return switch (this) {
      LayerAction.rename => AppIcon.edit,
      LayerAction.modify => AppIcon.transform,
      LayerAction.addAbove => AppIcon.playlistAdd,
      LayerAction.delete => AppIcon.playlistRemove,
      LayerAction.mergeBelow => AppIcon.layers,
      LayerAction.blendMode => AppIcon.blender,
      LayerAction.lock => layer.isLocked ? AppIcon.lock : AppIcon.lockOpen,
      LayerAction.visibility => layer.isVisible ? AppIcon.visibility : AppIcon.visibilityOff,
      LayerAction.hideOthers => AppIcon.visibilityOff,
      LayerAction.showAll => AppIcon.visibility,
    };
  }

  /// Tint of this action's icon for [layer]'s current state, or null for the
  /// surface default.
  Color? iconColor(LayerProvider layer) {
    return switch (this) {
      LayerAction.lock => layer.isLocked ? AppColors.layerHiddenWarning : null,
      LayerAction.visibility => layer.isVisible ? AppColors.primary : AppColors.layerHiddenWarning,
      _ => null,
    };
  }

  /// Menu label of this action for [layer]'s current state.
  String label(AppLocalizations l10n, LayerProvider layer) {
    return switch (this) {
      LayerAction.rename => l10n.layerRename,
      LayerAction.modify => l10n.layerModify,
      LayerAction.addAbove => l10n.layerAddAbove,
      LayerAction.delete => l10n.layerDelete,
      LayerAction.mergeBelow => l10n.layerMergeBelow,
      LayerAction.blendMode => l10n.layerChangeBlendMode,
      LayerAction.lock => layer.isLocked ? l10n.layerUnlockEdits : l10n.layerLockEdits,
      LayerAction.visibility => layer.isVisible ? l10n.layerHide : l10n.layerShow,
      LayerAction.hideOthers => l10n.layerHideAllOthers,
      LayerAction.showAll => l10n.layerShowAll,
    };
  }
}
