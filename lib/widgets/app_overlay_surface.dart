import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// Shared overlay surface styling for dialogs, sheets, and menus.
class AppOverlaySurface extends StatelessWidget {
  const AppOverlaySurface({
    super.key,
    required this.child,
    this.border,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.medium)),
    this.color = AppColors.surface,
    this.padding,
  });

  final BoxBorder? border;
  final BorderRadiusGeometry borderRadius;
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(final BuildContext context) {
    Widget content = child;

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border ?? Border.all(color: AppColors.overlayBorder, width: AppStroke.thin),
      ),
      child: content,
    );
  }
}
