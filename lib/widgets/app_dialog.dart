import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// Dialog content container replacing Material [AlertDialog].
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.titleIcon,
    this.content,
    this.actions,
  });
  final List<Widget>? actions;
  final Widget? content;

  /// The dialog title displayed as bold text.
  final String? title;

  /// An optional icon shown before the title text.
  final Widget? titleIcon;
  @override
  Widget build(final BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.dialogWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: AppColors.overlayBorder,
              width: AppStroke.thin,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (title != null)
                  DefaultTextStyle(
                    style: AppTextStyle.title,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.large),
                      child: titleIcon != null
                          ? Row(
                              spacing: AppSpacing.medium,
                              children: <Widget>[
                                titleIcon!,
                                Text(title!),
                              ],
                            )
                          : Text(title!),
                    ),
                  ),
                if (content != null)
                  Flexible(
                    child: SingleChildScrollView(
                      child: DefaultTextStyle(
                        style: AppTextStyle.body,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.large),
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
    barrierColor: AppColors.scrim,
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
