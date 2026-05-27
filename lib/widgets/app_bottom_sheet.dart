import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/app_overlay.dart';

/// Shows a modal bottom sheet replacing Material [showModalBottomSheet].
///
/// Pass [barrierColor] as [AppColors.transparent] to leave the background
/// fully visible (e.g. when the canvas should remain in view during the sheet).
Future<T?> showAppBottomSheet<T>({
  required final BuildContext context,
  required final WidgetBuilder builder,
  final Color barrierColor = AppColors.scrim,
}) {
  return showAppOverlay<T>(
    context: context,
    barrierColor: barrierColor,
    builder: (final BuildContext dialogContext) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * AppLayout.modalSheetMaxHeightFactor,
            maxWidth: AppLayout.modalSheetMaxWidth,
          ),
          child: AppOverlaySurface(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.medium),
            ),
            border: const Border(
              left: BorderSide(color: AppColors.overlayBorder, width: AppStroke.thin),
              top: BorderSide(color: AppColors.overlayBorder, width: AppStroke.thin),
              right: BorderSide(color: AppColors.overlayBorder, width: AppStroke.thin),
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
    this.title,
    this.titleIcon,
    this.titleTrailing,
  });

  /// The content to display inside the sheet scaffolding.
  final Widget child;

  /// Optional title displayed above the sheet content.
  final String? title;

  /// Optional icon shown before the title text.
  final Widget? titleIcon;

  /// Optional trailing widget shown on the title row.
  final Widget? titleTrailing;

  @override
  Widget build(final BuildContext context) {
    final Widget content = title == null
        ? child
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DefaultTextStyle(
                style: AppTextStyle.title,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.large),
                  child: Row(
                    spacing: AppSpacing.medium,
                    children: <Widget>[
                      ?titleIcon,
                      Expanded(
                        child: Text(title!),
                      ),
                      ?titleTrailing,
                    ],
                  ),
                ),
              ),
              child,
            ],
          );

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.modalSheetContentMaxWidth),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
