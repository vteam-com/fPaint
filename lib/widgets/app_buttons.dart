// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_tooltip.dart';

const int _subtleButtonBackgroundAlpha = 25;
const String _appButtonContentAssertionMessage = 'AppButton requires exactly one of child or builder.';

/// Shared semantic intents for button labels and icons.
///
/// These semantics describe foreground content colors independently from the
/// button surface, so different button families can share the same content
/// meaning while keeping their own background treatment.
enum AppButtonContentSemantic {
  /// Standard interactive content such as primary actions or neutral tools.
  enabled,

  /// Muted content for secondary or temporarily unavailable affordance.
  disabled,

  /// Destructive or cancel-oriented content that should stand out in red.
  dangerous,
}

/// Resolves the app-wide foreground color for [AppButtonContentSemantic].
extension AppButtonContentSemanticColorX on AppButtonContentSemantic {
  /// Semantic foreground color used by button labels and icons.
  Color get color {
    return switch (this) {
      AppButtonContentSemantic.enabled => AppColors.buttonEnable,
      AppButtonContentSemantic.disabled => AppColors.buttonDisable,
      AppButtonContentSemantic.dangerous => AppColors.buttonDanger,
    };
  }
}

/// Shared visual semantics for labeled button surfaces.
///
/// This keeps background, foreground, and spacing choices centralized for the
/// built-in text-button variants.
enum AppButtonLabelSemantic {
  /// Subtle emphasis used by lightweight actions.
  subtle,

  /// Strong filled emphasis used by primary actions.
  filled,

  /// Destructive emphasis used by risky actions.
  dangerous,
}

/// Resolves shared visual tokens for [AppButtonLabelSemantic].
extension AppButtonLabelSemanticStyleX on AppButtonLabelSemantic {
  /// Background color used by the labeled button surface.
  Color get backgroundColor {
    return switch (this) {
      AppButtonLabelSemantic.subtle => AppColors.primary.withAlpha(_subtleButtonBackgroundAlpha),
      AppButtonLabelSemantic.filled => AppColors.primary,
      AppButtonLabelSemantic.dangerous => AppColors.red.withAlpha(_subtleButtonBackgroundAlpha),
    };
  }

  /// Foreground semantic used by the labeled button content.
  AppButtonContentSemantic get contentSemantic {
    return switch (this) {
      AppButtonLabelSemantic.subtle => AppButtonContentSemantic.enabled,
      AppButtonLabelSemantic.filled => AppButtonContentSemantic.enabled,
      AppButtonLabelSemantic.dangerous => AppButtonContentSemantic.dangerous,
    };
  }

  /// Horizontal padding used by the labeled button surface.
  double get horizontalPadding {
    return switch (this) {
      AppButtonLabelSemantic.subtle => AppSpacing.big,
      AppButtonLabelSemantic.filled => AppSpacing.large,
      AppButtonLabelSemantic.dangerous => AppSpacing.big,
    };
  }
}

/// Immutable interaction snapshot passed to [AppButtonBuilder].
class AppButtonVisualState {
  /// Creates an [AppButtonVisualState].
  const AppButtonVisualState({
    required this.isHovered,
    required this.isPressed,
  });

  /// Whether the pointer is hovering over the button.
  final bool isHovered;

  /// Whether the button is actively pressed.
  final bool isPressed;
}

/// Builds button content from the current [AppButtonVisualState].
typedef AppButtonBuilder =
    Widget Function(
      BuildContext context,
      AppButtonVisualState state,
    );

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
    return _AppLabelButton(
      semantic: AppButtonLabelSemantic.subtle,
      onPressed: onPressed,
      text: text,
    );
  }
}

/// A destructive text button for irreversible or risky actions.
class AppButtonDanger extends StatelessWidget {
  const AppButtonDanger({
    super.key,
    required this.onPressed,
    required this.text,
  });
  final VoidCallback onPressed;
  final String text;
  @override
  Widget build(final BuildContext context) {
    return _AppLabelButton(
      semantic: AppButtonLabelSemantic.dangerous,
      onPressed: onPressed,
      text: text,
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
    return _AppLabelButton(
      semantic: AppButtonLabelSemantic.filled,
      onPressed: onPressed,
      text: text,
    );
  }
}

class _AppLabelButton extends StatelessWidget {
  const _AppLabelButton({
    required this.onPressed,
    required this.semantic,
    required this.text,
  });

  final VoidCallback onPressed;
  final AppButtonLabelSemantic semantic;
  final String text;

  @override
  Widget build(final BuildContext context) {
    return AppButton(
      onPressed: onPressed,
      hoverScale: AppVisual.full,
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: semantic.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: semantic.horizontalPadding,
            vertical: AppSpacing.medium,
          ),
          child: Center(
            child: DefaultTextStyle(
              style: AppTextStyle.button.copyWith(color: semantic.contentSemantic.color),
              child: Text(text),
            ),
          ),
        ),
      ),
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
    this.enabled = true,
    this.useSourceColors = false,
  });
  final Color? color;
  final BoxConstraints? constraints;
  final bool enabled;
  final AppIcon icon;
  final bool isSelected;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? padding;
  final double? size;
  final String? tooltip;
  final bool useSourceColors;

  @override
  Widget build(final BuildContext context) {
    return AppButton(
      onPressed: enabled ? onPressed : null,
      tooltip: enabled ? tooltip : null,
      constraints: constraints,
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      padding: padding,
      child: Opacity(
        opacity: enabled ? AppVisual.full : AppVisual.disabled,
        child: AppSvgIcon(
          icon: icon,
          isSelected: isSelected,
          color: color,
          size: size,
          useSourceColors: useSourceColors,
        ),
      ),
    );
  }
}

/// Shared base widget for all custom buttons in the app.
///
/// Supports either a static [child] or a state-driven [builder], optional
/// tooltip wrapping, hover and pressed transforms, pointer cursor control, and
/// both tap and drag gesture callbacks.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    this.child,
    this.builder,
    this.onPressed,
    this.tooltip,
    this.tooltipKey,
    this.constraints,
    this.cursor = SystemMouseCursors.click,
    this.padding,
    this.hoverScale = AppVisual.enlarge,
    this.pressedScale = AppVisual.shrink,
    this.pressedOpacity = AppVisual.full,
    this.animationDuration = AppDefaults.buttonTapAnimationDuration,
    this.animationCurve = Curves.easeOut,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
  }) : assert(
         (child == null) != (builder == null),
         _appButtonContentAssertionMessage,
       );

  /// Curve used by the scale and opacity transitions.
  final Curve animationCurve;

  /// Duration used by the scale and opacity transitions.
  final Duration animationDuration;

  /// Stateful content builder for advanced button variants.
  final AppButtonBuilder? builder;

  /// Static content for simple button variants.
  final Widget? child;

  final BoxConstraints? constraints;

  /// Mouse cursor shown while hovering.
  final MouseCursor cursor;

  /// Scale factor applied while hovered.
  final double hoverScale;

  /// Called when the drag is canceled.
  final GestureDragCancelCallback? onPanCancel;

  /// Called when a drag ends.
  final GestureDragEndCallback? onPanEnd;

  /// Called when a drag starts.
  final GestureDragStartCallback? onPanStart;

  /// Called on each drag update.
  final GestureDragUpdateCallback? onPanUpdate;

  /// Tap callback for standard button activation.
  final VoidCallback? onPressed;

  final EdgeInsetsGeometry? padding;

  /// Opacity applied while the button is pressed.
  final double pressedOpacity;

  /// Scale factor applied while pressed.
  final double pressedScale;

  final String? tooltip;

  /// Optional key forwarded to the wrapping tooltip widget.
  final Key? tooltipKey;
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
    final AppButtonVisualState state = AppButtonVisualState(
      isHovered: _isHovered,
      isPressed: _isPressed,
    );
    Widget content = widget.builder?.call(context, state) ?? widget.child!;

    content = AnimatedOpacity(
      opacity: _opacity,
      duration: widget.animationDuration,
      curve: widget.animationCurve,
      child: AnimatedScale(
        scale: _scale,
        duration: widget.animationDuration,
        curve: widget.animationCurve,
        child: ConstrainedBox(
          constraints: widget.constraints ?? const BoxConstraints(),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(AppSpacing.small),
            child: content,
          ),
        ),
      ),
    );

    Widget button = GestureDetector(
      onTapDown: widget.onPressed == null ? null : (final TapDownDetails _) => _setPressed(true),
      onTapUp: widget.onPressed == null ? null : (final TapUpDetails _) => _releasePressedWithMinimumDuration(),
      onTapCancel: widget.onPressed == null ? null : _releasePressedWithMinimumDuration,
      onTap: widget.onPressed,
      onPanStart: widget.onPanStart == null ? null : _handlePanStart,
      onPanUpdate: widget.onPanUpdate,
      onPanEnd: widget.onPanEnd == null ? null : _handlePanEnd,
      onPanCancel: widget.onPanCancel == null ? null : _handlePanCancel,
      child: MouseRegion(
        cursor: widget.cursor,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: content,
      ),
    );

    if (widget.tooltip != null) {
      button = AppTooltip(
        key: widget.tooltipKey,
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }

  void _handlePanCancel() {
    _setPressed(false);
    widget.onPanCancel?.call();
  }

  void _handlePanEnd(final DragEndDetails details) {
    _setPressed(false);
    widget.onPanEnd?.call(details);
  }

  void _handlePanStart(final DragStartDetails details) {
    _setPressed(true);
    widget.onPanStart?.call(details);
  }

  double get _opacity => _isPressed ? widget.pressedOpacity : AppVisual.full;

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
      return widget.pressedScale;
    }
    if (_isHovered) {
      return widget.hoverScale;
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
