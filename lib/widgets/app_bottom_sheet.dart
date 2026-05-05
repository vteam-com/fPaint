import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// Shows a modal bottom sheet replacing Material [showModalBottomSheet].
///
/// Pass [barrierColor] as [AppColors.transparent] to leave the background
/// fully visible (e.g. when the canvas should remain in view during the sheet).
Future<T?> showAppBottomSheet<T>({
  required final BuildContext context,
  required final WidgetBuilder builder,
  final Color barrierColor = AppColors.scrim,
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
                maxWidth: AppLayout.modalSheetMaxWidth,
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.medium),
                  ),
                  border: Border(
                    left: BorderSide(color: AppColors.overlayBorder, width: AppStroke.thin),
                    top: BorderSide(color: AppColors.overlayBorder, width: AppStroke.thin),
                    right: BorderSide(color: AppColors.overlayBorder, width: AppStroke.thin),
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

/// Standard content wrapper for [showAppBottomSheet] children.
///
/// Wraps [child] in [SafeArea], [SingleChildScrollView], standard padding,
/// centering, and a consistent max-width constraint so every sheet has the
/// same inner layout without repeating scaffolding at each call site.
class AppBottomSheetContent extends StatelessWidget {
  /// Creates an [AppBottomSheetContent].
  const AppBottomSheetContent({
    super.key,
    required this.child,
  });

  /// The content to display inside the sheet scaffolding.
  final Widget child;

  @override
  Widget build(final BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.modalSheetContentMaxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
