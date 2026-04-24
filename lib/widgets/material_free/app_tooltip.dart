import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// A tooltip widget replacing Material [Tooltip].
class AppTooltip extends StatefulWidget {
  const AppTooltip({
    super.key,
    required this.message,
    required this.child,
  });
  final Widget child;
  final String message;
  @override
  State<AppTooltip> createState() => _AppTooltipState();
}

class _AppTooltipState extends State<AppTooltip> {
  OverlayEntry? _overlayEntry;
  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return MouseRegion(
      onEnter: (final _) => _show(),
      onExit: (final _) => _hide(),
      child: widget.child,
    );
  }

  void _hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Inserts an [OverlayEntry] positioned below this widget to display the tooltip message.
  void _show() {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset target = box.localToGlobal(
      Offset(box.size.width / AppMath.pair, box.size.height),
    );

    _overlayEntry = OverlayEntry(
      builder: (final BuildContext _) {
        return Positioned(
          left: target.dx - AppLayout.toolbarButtonSize,
          top: target.dy + AppSpacing.xs,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  widget.message,
                  style: const TextStyle(color: AppPalette.white, fontSize: AppFontSize.subtitle),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }
}
