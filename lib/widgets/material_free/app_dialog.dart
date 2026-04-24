import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// Dialog content container replacing Material [AlertDialog].
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
  });
  final List<Widget>? actions;
  final Widget? content;
  final Widget? title;
  @override
  Widget build(final BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.dialogWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppPalette.overlayBorder,
              width: AppStroke.thin,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (title != null)
                  DefaultTextStyle(
                    style: const TextStyle(
                      fontFamily: appFontFamily,
                      color: AppPalette.white,
                      fontSize: AppFontSize.titleHero,
                      fontWeight: FontWeight.bold,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: title!,
                    ),
                  ),
                if (content != null)
                  Flexible(
                    child: SingleChildScrollView(
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          fontFamily: appFontFamily,
                          color: AppColors.textSecondary,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                          child: content!,
                        ),
                      ),
                    ),
                  ),
                if (actions != null && actions!.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a dialog using the widgets-layer [showGeneralDialog].
Future<T?> showAppDialog<T>({
  required final BuildContext context,
  required final WidgetBuilder builder,
  final bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabelDismiss,
    barrierColor: AppPalette.scrim,
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
