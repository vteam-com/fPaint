// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/app_tooltip.dart';

/// A text-only button replacing Material [TextButton].
class AppButtonText extends StatelessWidget {
  const AppButtonText({
    super.key,
    required this.onPressed,
    required this.text,
  });
  final VoidCallback onPressed;
  final String text;
  @override
  Widget build(final BuildContext context) {
    return _AppButtonBase(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      textColor: AppColors.primary,
      child: Text(text),
    );
  }
}

/// A filled button replacing Material [ElevatedButton].
class AppButtonPrimary extends StatelessWidget {
  const AppButtonPrimary({
    super.key,
    required this.onPressed,
    required this.text,
  });
  final VoidCallback onPressed;
  final String text;
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
      child: Text(text),
    );
  }
}

/// An icon button replacing Material [IconButton].
class AppButtonIcon extends StatefulWidget {
  const AppButtonIcon({
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
  State<AppButtonIcon> createState() => _AppButtonIconState();
}

class _AppButtonIconState extends State<AppButtonIcon> {
  bool _isHovered = false;
  bool _isPressed = false;
  @override
  Widget build(final BuildContext context) {
    Widget button = GestureDetector(
      onTapDown: (final TapDownDetails _) => _setPressed(true),
      onTapUp: (final TapUpDetails _) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: AnimatedScale(
          scale: _scale,
          duration: AppDefaults.buttonTapAnimationDuration,
          curve: Curves.easeOut,
          child: ConstrainedBox(
            constraints: widget.constraints ?? const BoxConstraints(),
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(AppSpacing.sm),
              child: widget.icon,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = AppTooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }

  double get _scale {
    if (_isPressed) {
      return AppVisual.shrink;
    }
    if (_isHovered) {
      return AppVisual.enlarge;
    }
    return AppVisual.full;
  }

  void _setHovered(final bool isHovered) {
    if (_isHovered == isHovered) {
      return;
    }
    setState(() {
      _isHovered = isHovered;
    });
  }

  void _setPressed(final bool isPressed) {
    if (_isPressed == isPressed) {
      return;
    }
    setState(() {
      _isPressed = isPressed;
    });
  }
}

/// Shared base for [AppButtonText] and [AppButtonPrimary].
class _AppButtonBase extends StatefulWidget {
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
  State<_AppButtonBase> createState() => _AppButtonBaseState();
}

class _AppButtonBaseState extends State<_AppButtonBase> {
  bool _isPressed = false;
  @override
  Widget build(final BuildContext context) {
    Widget content = Padding(
      padding: widget.padding,
      child: Center(
        child: DefaultTextStyle(
          style: AppTextStyle.button.copyWith(color: widget.textColor),
          child: widget.child,
        ),
      ),
    );

    if (widget.backgroundColor != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.borderRadius ?? 0),
        ),
        child: content,
      );
    }

    content = AnimatedScale(
      scale: _isPressed ? AppVisual.shrink : AppVisual.full,
      duration: AppDefaults.buttonTapAnimationDuration,
      curve: Curves.easeOut,
      child: content,
    );

    return GestureDetector(
      onTapDown: (final TapDownDetails _) => _setPressed(true),
      onTapUp: (final TapUpDetails _) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: content,
      ),
    );
  }

  void _setPressed(final bool isPressed) {
    if (_isPressed == isPressed) {
      return;
    }
    setState(() {
      _isPressed = isPressed;
    });
  }
}
