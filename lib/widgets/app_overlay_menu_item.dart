import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// Shared tappable menu item styling for dropdowns and popup menus.
class AppOverlayMenuItem extends StatelessWidget {
  const AppOverlayMenuItem({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.medium,
          ),
          child: DefaultTextStyle(
            style: AppTextStyle.body,
            child: child,
          ),
        ),
      ),
    );
  }
}
