// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
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
        horizontal: AppSpacing.big,
        vertical: AppSpacing.medium,
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
        horizontal: AppSpacing.large,
        vertical: AppSpacing.medium,
      ),
      textColor: AppColors.white,
      backgroundColor: AppColors.primary,
      borderRadius: AppRadius.small,
      child: Text(text),
    );
  }
}

/// An icon button replacing Material [IconButton].
class AppButtonIcon extends StatelessWidget {
  const AppButtonIcon({
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
  Widget build(final BuildContext context) {
    return AppButton(
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: constraints,
      padding: padding,
      child: AppSvgIcon(
        icon: icon,
        isSelected: isSelected,
        color: color,
        size: size,
      ),
    );
  }
}

/// A generic image button variant for custom icon widgets.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.tooltip,
    this.constraints,
    this.padding,
  });
  final Widget child;
  final BoxConstraints? constraints;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;
  @override
  State<AppButton> createState() => _AppButtonState();
}

/// Shares minimum press-duration behavior across button variants so quick taps
/// still paint at least one visible pressed frame.
mixin _MinimumPressDurationStateMixin<T extends StatefulWidget> on State<T> {
  int _pressToken = 0;

  /// Marks the beginning of a new press cycle.
  void markPressed() {
    _pressToken++;
  }

  /// Defers release to the next frame so quick taps still paint the pressed
  /// state at least once without introducing timer-based test flakiness.
  void releasePressedOnNextFrame({
    required final bool isPressed,
    required final bool Function() isStillPressed,
    required final VoidCallback release,
  }) {
    if (!isPressed) {
      return;
    }
    final int token = _pressToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _pressToken || !isStillPressed()) {
        return;
      }
      release();
    });
  }
}

class _AppButtonState extends State<AppButton> with _MinimumPressDurationStateMixin<AppButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  @override
  Widget build(final BuildContext context) {
    Widget button = GestureDetector(
      onTapDown: (final TapDownDetails _) => _setPressed(true),
      onTapUp: (final TapUpDetails _) => _releasePressedWithMinimumDuration(),
      onTapCancel: _releasePressedWithMinimumDuration,
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
              padding: widget.padding ?? const EdgeInsets.all(AppSpacing.small),
              child: widget.child,
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

  /// Releases icon pressed state while guaranteeing a visible press frame.
  void _releasePressedWithMinimumDuration() {
    releasePressedOnNextFrame(
      isPressed: _isPressed,
      isStillPressed: () => _isPressed,
      release: () => _setPressed(false),
    );
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

  /// Toggles icon pressed state and tracks press-cycle metadata.
  void _setPressed(final bool isPressed) {
    if (_isPressed == isPressed) {
      return;
    }
    if (isPressed) {
      markPressed();
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

class _AppButtonBaseState extends State<_AppButtonBase> with _MinimumPressDurationStateMixin<_AppButtonBase> {
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
      onTapUp: (final TapUpDetails _) => _releasePressedWithMinimumDuration(),
      onTapCancel: _releasePressedWithMinimumDuration,
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: content,
      ),
    );
  }

  /// Releases base button pressed state while guaranteeing a visible press frame.
  void _releasePressedWithMinimumDuration() {
    releasePressedOnNextFrame(
      isPressed: _isPressed,
      isStillPressed: () => _isPressed,
      release: () => _setPressed(false),
    );
  }

  /// Toggles base button pressed state and tracks press-cycle metadata.
  void _setPressed(final bool isPressed) {
    if (_isPressed == isPressed) {
      return;
    }
    if (isPressed) {
      markPressed();
    }
    setState(() {
      _isPressed = isPressed;
    });
  }
}
