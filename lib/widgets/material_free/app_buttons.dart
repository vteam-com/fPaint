// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/material_free/app_tooltip.dart';

/// A text-only button replacing Material [TextButton].
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.onPressed,
    required this.child,
  });
  final Widget child;
  final VoidCallback onPressed;
  @override
  Widget build(final BuildContext context) {
    return _AppButtonBase(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      textColor: AppColors.primary,
      child: child,
    );
  }
}

/// A filled button replacing Material [ElevatedButton].
class AppElevatedButton extends StatelessWidget {
  const AppElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
  });
  final Widget child;
  final VoidCallback onPressed;
  @override
  Widget build(final BuildContext context) {
    return _AppButtonBase(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      textColor: AppPalette.white,
      backgroundColor: AppColors.primary,
      borderRadius: AppRadius.sm,
      child: child,
    );
  }
}

/// Shared base for [AppTextButton] and [AppElevatedButton].
class _AppButtonBase extends StatelessWidget {
  const _AppButtonBase({
    required this.onPressed,
    required this.padding,
    required this.textColor,
    required this.child,
    this.backgroundColor,
    this.borderRadius,
  });
  final Color? backgroundColor;
  final double? borderRadius;
  final Widget child;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final Color textColor;
  @override
  Widget build(final BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: appFontFamily,
          color: textColor,
          fontSize: AppFontSize.titleHero,
        ),
        child: child,
      ),
    );

    if (backgroundColor != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius ?? 0),
        ),
        child: content,
      );
    }

    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: content,
      ),
    );
  }
}

/// An icon button replacing Material [IconButton].
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.constraints,
    this.padding,
  });
  final BoxConstraints? constraints;
  final Widget icon;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;
  @override
  Widget build(final BuildContext context) {
    Widget button = GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: constraints ?? const BoxConstraints(),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.sm),
            child: icon,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = AppTooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
