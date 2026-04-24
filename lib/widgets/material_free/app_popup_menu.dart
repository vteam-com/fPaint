// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// A popup menu item replacing Material [PopupMenuItem].
class AppPopupMenuItem<T> {
  const AppPopupMenuItem({
    required this.value,
    required this.child,
  });

  final T value;
  final Widget child;
}

/// Shows a popup menu at the given position, replacing Material [showMenu].
Future<T?> showAppMenu<T>({
  required final BuildContext context,
  required final RelativeRect position,
  required final List<AppPopupMenuItem<T>> items,
}) async {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final Size overlaySize = overlay.size;

  T? selectedValue;

  await showGeneralDialog<void>(
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
              // Tap anywhere to dismiss.
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              Positioned(
                left: position.left.clamp(0, overlaySize.width - _menuMinWidth),
                top: position.top.clamp(0, overlaySize.height - _menuItemHeight),
                child: IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: _menuMinWidth,
                      maxHeight: overlaySize.height - position.top.clamp(0, overlaySize.height - _menuItemHeight),
                    ),
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
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: items.map((final AppPopupMenuItem<T> item) {
                              return GestureDetector(
                                onTap: () {
                                  selectedValue = item.value;
                                  Navigator.pop(dialogContext);
                                },
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xl,
                                      vertical: AppSpacing.md,
                                    ),
                                    child: DefaultTextStyle(
                                      style: const TextStyle(
                                        fontFamily: appFontFamily,
                                        color: AppPalette.white,
                                      ),
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
                  ),
                ),
              ),
            ],
          );
        },
  );

  return selectedValue;
}

const double _menuMinWidth = 200.0;
const double _menuItemHeight = 48.0;

/// A button that opens a popup menu, replacing Material [PopupMenuButton].
class AppPopupMenuButton<T> extends StatelessWidget {
  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
    this.icon,
    this.tooltip,
  });
  final Widget? icon;
  final List<AppPopupMenuItem<T>> Function(BuildContext context) itemBuilder;
  final void Function(T value) onSelected;
  final String? tooltip;
  @override
  Widget build(final BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final RenderBox button = context.findRenderObject()! as RenderBox;
        final Offset offset = button.localToGlobal(
          Offset(0, button.size.height),
        );
        final T? value = await showAppMenu<T>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy,
            offset.dx,
            offset.dy,
          ),
          items: itemBuilder(context),
        );
        if (value != null) {
          onSelected(value);
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: icon ?? const SizedBox.shrink(),
      ),
    );
  }
}
