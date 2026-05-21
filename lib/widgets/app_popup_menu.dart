// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_overlay.dart';

/// A popup menu item replacing Material [PopupMenuItem].
class AppPopupMenuItem<T> {
  const AppPopupMenuItem({
    required this.value,
    required this.child,
    this.key,
  });

  final T value;
  final Widget child;
  final Key? key;
}

/// Shows a popup menu at the given position, replacing Material [showMenu].
Future<T?> showAppMenu<T>({
  required final BuildContext context,
  required final RelativeRect position,
  required final List<AppPopupMenuItem<T>> items,
}) async {
  final OverlayState overlayState = Overlay.of(context);
  final RenderObject? overlayRenderObject = overlayState.context.findRenderObject();
  if (overlayRenderObject is! RenderBox) {
    return null;
  }
  final RenderBox overlay = overlayRenderObject;
  final Size overlaySize = overlay.size;

  return showAppOverlay<T>(
    context: context,
    barrierColor: AppColors.transparent,
    builder: (final BuildContext dialogContext) {
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(dialogContext),
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            left: position.left.clamp(0, overlaySize.width - AppLayout.popupMenuMinWidth),
            top: position.top.clamp(0, overlaySize.height - AppLayout.popupMenuItemHeight),
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: AppLayout.popupMenuMinWidth,
                  maxHeight:
                      overlaySize.height - position.top.clamp(0, overlaySize.height - AppLayout.popupMenuItemHeight),
                ),
                child: AppOverlaySurface(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: items.map((final AppPopupMenuItem<T> item) {
                        return AppOverlayMenuItem(
                          key: item.key,
                          onTap: () => Navigator.pop(dialogContext, item.value),
                          child: item.child,
                        );
                      }).toList(),
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
}

/// A button that opens a popup menu, replacing Material [PopupMenuButton].
class AppPopupMenuButton<T> extends StatelessWidget {
  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
    required this.child,
    this.tooltip,
  });
  final Widget child;
  final List<AppPopupMenuItem<T>> Function(BuildContext context) itemBuilder;
  final void Function(T value) onSelected;
  final String? tooltip;
  @override
  Widget build(final BuildContext context) {
    return AppButton(
      tooltip: tooltip,
      onPressed: () async {
        final RenderObject? buttonRenderObject = context.findRenderObject();
        if (buttonRenderObject is! RenderBox) {
          return;
        }
        final RenderBox button = buttonRenderObject;
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
        if (!context.mounted) {
          return;
        }
        if (value != null) {
          onSelected(value);
        }
      },
      child: child,
    );
  }
}
