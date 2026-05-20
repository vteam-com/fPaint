import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

export 'app_overlay_menu_item.dart';
export 'app_overlay_surface.dart';

/// Shows a general-purpose application overlay with consistent barrier setup.
Future<T?> showAppOverlay<T>({
  required final BuildContext context,
  required final WidgetBuilder builder,
  final bool barrierDismissible = true,
  final Color barrierColor = AppColors.scrim,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabelDismiss,
    barrierColor: barrierColor,
    pageBuilder:
        (
          final BuildContext dialogContext,
          final Animation<double> _,
          final Animation<double> _,
        ) {
          return builder(dialogContext);
        },
  );
}
