import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// Shows a modal bottom sheet replacing Material [showModalBottomSheet].
///
/// Pass [barrierColor] as [AppPalette.transparent] to leave the background
/// fully visible (e.g. when the canvas should remain in view during the sheet).
Future<T?> showAppBottomSheet<T>({
  required final BuildContext context,
  required final WidgetBuilder builder,
  final Color barrierColor = AppPalette.scrim,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabelDismiss,
    barrierColor: barrierColor,
    pageBuilder:
        (
          final BuildContext dialogContext,
          final Animation<double> _,
          final Animation<double> _,
        ) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * AppLayout.modalSheetMaxHeightFactor,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.md),
                  ),
                  border: Border.all(
                    color: AppPalette.overlayBorder,
                    width: AppStroke.thin,
                  ),
                ),
                child: DefaultTextStyle(
                  style: AppTextStyle.body,
                  child: builder(dialogContext),
                ),
              ),
            ),
          );
        },
  );
}
