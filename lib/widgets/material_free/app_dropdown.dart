// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// A dropdown button replacement for Material [DropdownButton].
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final T? value;
  @override
  Widget build(final BuildContext context) {
    final AppDropdownItem<T>? selected = items.cast<AppDropdownItem<T>?>().firstWhere(
      (final AppDropdownItem<T>? item) => item?.value == value,
      orElse: () => null,
    );

    return GestureDetector(
      onTap: () async {
        final RenderBox button = context.findRenderObject()! as RenderBox;
        final Offset offset = button.localToGlobal(
          Offset(0, button.size.height),
        );
        final T? result = await showGeneralDialog<T>(
          context: context,
          barrierDismissible: true,
          barrierLabel: barrierLabelDismiss,
          barrierColor: const Color(0x00000000),
          pageBuilder:
              (
                final BuildContext dialogContext,
                final Animation<double> _,
                final Animation<double> _,
              ) {
                return Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        behavior: HitTestBehavior.opaque,
                      ),
                    ),
                    Positioned(
                      left: offset.dx,
                      top: offset.dy,
                      child: IntrinsicWidth(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppPalette.overlayBorder,
                              width: AppStroke.thin,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: items.map((final AppDropdownItem<T> item) {
                              return GestureDetector(
                                onTap: () => Navigator.pop(dialogContext, item.value),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xl,
                                      vertical: AppSpacing.md,
                                    ),
                                    child: DefaultTextStyle(
                                      style: const TextStyle(color: AppPalette.white),
                                      child: item.child,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
        );
        if (result != null) {
          onChanged(result);
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: IntrinsicWidth(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DefaultTextStyle(
                    style: const TextStyle(color: AppPalette.white),
                    child: selected?.child ?? const SizedBox.shrink(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text(
                    '▼',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSize.subtitle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An item in an [AppDropdown], replacing Material [DropdownMenuItem].
class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    required this.child,
  });

  final T? value;
  final Widget child;
}
