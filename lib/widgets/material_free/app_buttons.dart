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
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: appFontFamily,
              color: AppColors.primary,
              fontSize: AppFontSize.titleHero,
            ),
            child: child,
          ),
        ),
      ),
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
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: appFontFamily,
                color: AppPalette.white,
                fontSize: AppFontSize.titleHero,
              ),
              child: child,
            ),
          ),
        ),
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
