// ignore: fcheck_one_class_per_file
import 'package:flutter/widget_previews.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_buttons.dart';

const String _previewTextDelete = 'Delete';
const String _previewTextCancel = 'Cancel';
const String _previewTextApply = 'Apply';
const String _previewTextReplace = 'Replace';
const String _previewTextRotate = 'Rotate';
const String _previewTextFlip = 'Flip';
const String previewNameAppRowDangerButton = 'AppRowDangerButton';
const String previewNameAppRowIconButton = 'AppRowIconButton';
const String previewNameAppRowSecondaryButton = 'AppRowSecondaryButton';
const String previewNameAppRowPrimaryButton = 'AppRowPrimaryButton';
const String previewNameAppButtonRowDefault = 'AppButtonRowDefault';
const String previewNameAppButtonRowWithIcon = 'AppButtonRowWithIcon';
const String previewNameAppButtonRowCompact = 'AppButtonRowCompact';
const double _previewWideContainerWidth = AppLayout.sidePanelExpandedMin;

/// Semantic placement slots supported by [AppButtonRow].
enum AppButtonRowSlot {
  danger,
  icon,
  secondary,
  primary,
}

/// Standardized dialog action layout with left, center, and right groups.
class AppButtonRow extends StatelessWidget {
  const AppButtonRow({
    super.key,
    required this.actions,
  });

  final List<Widget> actions;

  @override
  Widget build(final BuildContext context) {
    final _AppButtonRowGroups groups = _AppButtonRowGroups.fromActions(actions);
    final List<Widget> trailingActions = <Widget>[
      ...groups.secondary,
      ...groups.primary,
    ];

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (groups.danger.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: _AppButtonRowGroup(
                actions: groups.danger,
                verticalAlignment: CrossAxisAlignment.start,
              ),
            ),
          if (groups.icon.isNotEmpty)
            Align(
              alignment: Alignment.center,
              child: _AppButtonRowGroup(
                actions: groups.icon,
                verticalAlignment: CrossAxisAlignment.center,
              ),
            ),
          if (trailingActions.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: _AppButtonRowGroup(
                actions: trailingActions,
                verticalAlignment: CrossAxisAlignment.end,
              ),
            ),
        ],
      ),
    );
  }
}

/// Base contract for widgets that declare an explicit dialog action slot.
abstract class AppButtonRowWidget extends StatelessWidget {
  const AppButtonRowWidget({super.key});

  /// Placement slot used by [AppButtonRow] when grouping this action.
  AppButtonRowSlot get slot;
}

/// Semantic dialog action rendered in the destructive left-side slot.
class AppRowDangerButton extends AppButtonRowWidget {
  const AppRowDangerButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  final VoidCallback onPressed;
  final String text;

  @override
  AppButtonRowSlot get slot => AppButtonRowSlot.danger;

  @override
  Widget build(final BuildContext context) {
    return AppButtonDanger(
      onPressed: onPressed,
      text: text,
    );
  }
}

/// Semantic dialog action rendered in the centered icon slot.
class AppRowIconButton extends AppButtonRowWidget {
  const AppRowIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isSelected = false,
    this.color,
    this.size,
    this.tooltip,
    this.constraints,
    this.padding,
  });

  final Color? color;
  final BoxConstraints? constraints;
  final AppIcon icon;
  final bool isSelected;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? padding;
  final double? size;
  final String? tooltip;

  @override
  AppButtonRowSlot get slot => AppButtonRowSlot.icon;

  @override
  Widget build(final BuildContext context) {
    return AppButtonIcon(
      icon: icon,
      onPressed: onPressed,
      isSelected: isSelected,
      color: color,
      size: size,
      tooltip: tooltip,
      constraints: constraints,
      padding: padding,
    );
  }
}

/// Semantic dialog action rendered on the right before primaries.
class AppRowSecondaryButton extends AppButtonRowWidget {
  const AppRowSecondaryButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  final VoidCallback onPressed;
  final String text;

  @override
  AppButtonRowSlot get slot => AppButtonRowSlot.secondary;

  @override
  Widget build(final BuildContext context) {
    return AppButtonText(
      onPressed: onPressed,
      text: text,
    );
  }
}

/// Semantic dialog action rendered at the far right.
class AppRowPrimaryButton extends AppButtonRowWidget {
  const AppRowPrimaryButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  final VoidCallback onPressed;
  final String text;

  @override
  AppButtonRowSlot get slot => AppButtonRowSlot.primary;

  @override
  Widget build(final BuildContext context) {
    return AppButtonPrimary(
      onPressed: onPressed,
      text: text,
    );
  }
}

class _AppButtonRowGroup extends StatelessWidget {
  const _AppButtonRowGroup({
    required this.actions,
    required this.verticalAlignment,
  });
  final List<Widget> actions;
  final CrossAxisAlignment verticalAlignment;
  @override
  Widget build(final BuildContext context) {
    return LayoutBuilder(
      builder: (final BuildContext _, final BoxConstraints constraints) {
        if (_shouldStackVertically(constraints.maxWidth)) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: verticalAlignment,
            spacing: AppSpacing.medium,
            children: actions,
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.medium,
          children: actions,
        );
      },
    );
  }

  /// Returns a coarse width estimate for [action] so narrow containers can stack safely.
  double _estimatedActionWidth(final Widget action) {
    return _describeAppButtonRowAction(action).estimatedWidth;
  }

  /// Estimated minimum width needed to keep all actions on one horizontal line.
  double get _estimatedHorizontalWidth {
    if (actions.isEmpty) {
      return 0.0;
    }

    final double contentWidth = actions.fold<double>(
      0.0,
      (final double total, final Widget action) => total + _estimatedActionWidth(action),
    );
    final int gaps = actions.length - 1;
    return contentWidth + (gaps * AppSpacing.medium);
  }

  bool _shouldStackVertically(final double maxWidth) {
    return maxWidth.isFinite && maxWidth < _estimatedHorizontalWidth;
  }
}

class _AppButtonRowGroups {
  factory _AppButtonRowGroups.fromActions(final List<Widget> actions) {
    final List<Widget> danger = <Widget>[];
    final List<Widget> icon = <Widget>[];
    final List<Widget> secondary = <Widget>[];
    final List<Widget> primary = <Widget>[];

    for (final Widget action in actions) {
      switch (_describeAppButtonRowAction(action).slot) {
        case AppButtonRowSlot.danger:
          danger.add(action);
        case AppButtonRowSlot.icon:
          icon.add(action);
        case AppButtonRowSlot.secondary:
          secondary.add(action);
        case AppButtonRowSlot.primary:
          primary.add(action);
      }
    }

    return _AppButtonRowGroups(
      danger: danger,
      icon: icon,
      secondary: secondary,
      primary: primary,
    );
  }
  const _AppButtonRowGroups({
    required this.danger,
    required this.icon,
    required this.secondary,
    required this.primary,
  });

  final List<Widget> danger;
  final List<Widget> icon;
  final List<Widget> primary;
  final List<Widget> secondary;
}

/// Maps each supported action widget to the semantic button-row slot metadata
/// used by both grouping and width estimation.
_AppButtonRowActionDescription _describeAppButtonRowAction(final Widget action) {
  if (action is AppButtonRowWidget) {
    return _actionDescriptionForButtonRowSlot(action.slot);
  }
  if (action is AppButtonDanger) {
    return _actionDescriptionForButtonRowSlot(AppButtonRowSlot.danger);
  }
  if (action is AppButtonPrimary) {
    return _actionDescriptionForButtonRowSlot(AppButtonRowSlot.primary);
  }
  if (action is AppButtonIcon) {
    return _actionDescriptionForButtonRowSlot(AppButtonRowSlot.icon);
  }
  return _actionDescriptionForButtonRowSlot(AppButtonRowSlot.secondary);
}

/// Returns the shared layout metadata for a semantic button-row slot so all
/// row calculations stay aligned on a single source of truth.
_AppButtonRowActionDescription _actionDescriptionForButtonRowSlot(
  final AppButtonRowSlot slot,
) {
  return switch (slot) {
    AppButtonRowSlot.icon => const _AppButtonRowActionDescription(
      slot: AppButtonRowSlot.icon,
      estimatedWidth: AppLayout.toolbarButtonSize,
    ),
    AppButtonRowSlot.danger => const _AppButtonRowActionDescription(
      slot: AppButtonRowSlot.danger,
      estimatedWidth: AppLayout.toolbarButtonWidth + AppSpacing.large,
    ),
    AppButtonRowSlot.secondary => const _AppButtonRowActionDescription(
      slot: AppButtonRowSlot.secondary,
      estimatedWidth: AppLayout.toolbarButtonWidth + AppSpacing.large,
    ),
    AppButtonRowSlot.primary => const _AppButtonRowActionDescription(
      slot: AppButtonRowSlot.primary,
      estimatedWidth: AppLayout.toolbarButtonWidth + AppSpacing.large,
    ),
  };
}

class _AppButtonRowActionDescription {
  const _AppButtonRowActionDescription({
    required this.slot,
    required this.estimatedWidth,
  });

  final double estimatedWidth;
  final AppButtonRowSlot slot;
}

/// Wraps button-row previews with directionality and a constrained width.
Widget _buildButtonRowPreviewContainer({
  required final double width,
  required final Widget child,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: width,
        child: child,
      ),
    ),
  );
}

void _noopButtonRowPreviewAction() {}

/// Widget preview entry for [AppRowDangerButton].
@Preview(name: previewNameAppRowDangerButton)
Widget appRowDangerButtonPreview() {
  return _buildButtonRowPreviewContainer(
    width: _previewWideContainerWidth,
    child: const AppRowDangerButton(
      onPressed: _noopButtonRowPreviewAction,
      text: _previewTextDelete,
    ),
  );
}

/// Widget preview entry for [AppRowIconButton].
@Preview(name: previewNameAppRowIconButton)
Widget appRowIconButtonPreview() {
  return _buildButtonRowPreviewContainer(
    width: _previewWideContainerWidth,
    child: const AppRowIconButton(
      icon: AppIcon.refresh,
      onPressed: _noopButtonRowPreviewAction,
      tooltip: _previewTextReplace,
    ),
  );
}

/// Widget preview entry for [AppRowSecondaryButton].
@Preview(name: previewNameAppRowSecondaryButton)
Widget appRowSecondaryButtonPreview() {
  return _buildButtonRowPreviewContainer(
    width: _previewWideContainerWidth,
    child: const AppRowSecondaryButton(
      onPressed: _noopButtonRowPreviewAction,
      text: _previewTextCancel,
    ),
  );
}

/// Widget preview entry for [AppRowPrimaryButton].
@Preview(name: previewNameAppRowPrimaryButton)
Widget appRowPrimaryButtonPreview() {
  return _buildButtonRowPreviewContainer(
    width: _previewWideContainerWidth,
    child: const AppRowPrimaryButton(
      onPressed: _noopButtonRowPreviewAction,
      text: _previewTextApply,
    ),
  );
}

/// Widget preview entry for [AppButtonRow] with danger and trailing actions.
@Preview(name: previewNameAppButtonRowDefault, size: Size(600, 60))
Widget appButtonRowDefaultPreview() {
  return const AppButtonRow(
    actions: <Widget>[
      AppRowDangerButton(
        onPressed: _noopButtonRowPreviewAction,
        text: _previewTextDelete,
      ),
      AppRowSecondaryButton(
        onPressed: _noopButtonRowPreviewAction,
        text: _previewTextCancel,
      ),
      AppRowPrimaryButton(
        onPressed: _noopButtonRowPreviewAction,
        text: _previewTextApply,
      ),
    ],
  );
}

/// Widget preview entry for [AppButtonRow] including centered icon controls.
@Preview(name: previewNameAppButtonRowWithIcon, size: Size(600, 60))
Widget appButtonRowWithIconPreview() {
  return const AppButtonRow(
    actions: <Widget>[
      AppRowIconButton(
        icon: AppIcon.rotateRight,
        onPressed: _noopButtonRowPreviewAction,
        tooltip: _previewTextRotate,
      ),
      AppRowIconButton(
        icon: AppIcon.flipHorizontal,
        onPressed: _noopButtonRowPreviewAction,
        tooltip: _previewTextFlip,
      ),
      AppRowSecondaryButton(
        onPressed: _noopButtonRowPreviewAction,
        text: _previewTextCancel,
      ),
      AppRowPrimaryButton(
        onPressed: _noopButtonRowPreviewAction,
        text: _previewTextApply,
      ),
    ],
  );
}

/// Widget preview entry for [AppButtonRow] in narrow containers.
@Preview(name: previewNameAppButtonRowCompact, size: Size(100, 100))
Widget appButtonRowCompactPreview() {
  return const AppButtonRow(
    actions: <Widget>[
      AppRowSecondaryButton(
        onPressed: _noopButtonRowPreviewAction,
        text: _previewTextCancel,
      ),
      AppRowPrimaryButton(
        onPressed: _noopButtonRowPreviewAction,
        text: _previewTextApply,
      ),
    ],
  );
}
