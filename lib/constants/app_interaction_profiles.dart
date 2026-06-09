import 'app_interaction.dart';
import 'app_layout.dart';
import 'interaction_input_modality.dart';
import 'interaction_layout_profile.dart';

/// Shared interaction profiles for desktop mouse and tablet touch/pen flows.
class AppInteractionProfiles {
  static const InteractionLayoutProfile mouse = InteractionLayoutProfile(
    buttonSize: AppInteraction.imagePlacementButtonSize,
    buttonSpacing: AppInteraction.imagePlacementButtonSpacing,
    dragHandleSize: AppInteraction.selectionHandleSize,
    edgeHandleSize: AppInteraction.transformEdgeHandleSize,
    imagePlacementHandleSize: AppInteraction.imagePlacementHandleSize,
    floatingButtonSize: AppLayout.toolbarButtonSize,
    iconSize: AppLayout.iconSize,
  );

  static const double _tabletButtonSize = 42.0;
  static const double _tabletTouchButtonSize = 48.0;
  static const double _tabletPenDragHandleSize = 24.0;
  static const double _tabletTouchDragHandleSize = 28.0;
  static const double _tabletPenImageHandleSize = 20.0;
  static const double _tabletTouchImageHandleSize = 24.0;
  static const double _tabletEdgeHandleSize = 18.0;
  static const double _tabletPenFloatingButtonSize = 56.0;
  static const double _tabletTouchFloatingButtonSize = 60.0;
  static const double _tabletButtonSpacing = 10.0;
  static const double _tabletTouchButtonSpacing = 12.0;
  static const double _tabletIconSize = 24.0;

  static const InteractionLayoutProfile pen = InteractionLayoutProfile(
    buttonSize: _tabletButtonSize,
    buttonSpacing: _tabletButtonSpacing,
    dragHandleSize: _tabletPenDragHandleSize,
    edgeHandleSize: _tabletEdgeHandleSize,
    imagePlacementHandleSize: _tabletPenImageHandleSize,
    floatingButtonSize: _tabletPenFloatingButtonSize,
    iconSize: _tabletIconSize,
  );

  static const InteractionLayoutProfile touch = InteractionLayoutProfile(
    buttonSize: _tabletTouchButtonSize,
    buttonSpacing: _tabletTouchButtonSpacing,
    dragHandleSize: _tabletTouchDragHandleSize,
    edgeHandleSize: _tabletEdgeHandleSize,
    imagePlacementHandleSize: _tabletTouchImageHandleSize,
    floatingButtonSize: _tabletTouchFloatingButtonSize,
    iconSize: _tabletIconSize,
  );

  /// Returns the interaction layout profile that matches [modality].
  static InteractionLayoutProfile forModality(final InteractionInputModality modality) {
    switch (modality) {
      case InteractionInputModality.pen:
        return pen;
      case InteractionInputModality.touch:
        return touch;
      case InteractionInputModality.mouse:
        return mouse;
    }
  }
}
