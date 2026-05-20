// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_buttons.dart';

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
    if (action is AppButtonIcon || action is AppRowIconButton) {
      return AppLayout.toolbarButtonSize;
    }

    if (action is AppButtonDanger ||
        action is AppButtonPrimary ||
        action is AppButtonText ||
        action is AppRowDangerButton ||
        action is AppRowPrimaryButton ||
        action is AppRowSecondaryButton) {
      return AppLayout.toolbarButtonWidth + AppSpacing.large;
    }

    return AppLayout.toolbarButtonWidth;
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
      switch (_resolveActionSlot(action)) {
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

  /// Resolves [action] into a dialog slot, including legacy button widgets.
  static AppButtonRowSlot _resolveActionSlot(final Widget action) {
    if (action is AppButtonRowWidget) {
      return action.slot;
    }
    if (action is AppButtonDanger) {
      return AppButtonRowSlot.danger;
    }
    if (action is AppButtonPrimary) {
      return AppButtonRowSlot.primary;
    }
    if (action is AppButtonIcon) {
      return AppButtonRowSlot.icon;
    }
    return AppButtonRowSlot.secondary;
  }
}
