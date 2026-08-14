import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

export 'app_overlay_menu_item.dart';
export 'app_overlay_surface.dart';

/// Shows a general-purpose application overlay with consistent barrier setup.
Future<T?> showAppOverlay<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = AppColors.scrim,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabelDismiss,
    barrierColor: barrierColor,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> _,
          Animation<double> _,
        ) {
          return builder(dialogContext);
        },
  );
}
