// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_overlay.dart';
import 'package:fpaint/widgets/app_text.dart';

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

/// Builds the standard popup menu entry: an optional leading [icon] (tinted
/// [iconColor]), the [text] label and an optional [subtitle] line beneath it.
///
/// [key] is placed on the entry's content row so tests can find it.
AppPopupMenuItem<T> buildMenuItem<T>({
  required T value,
  required String text,
  String? subtitle,
  AppIcon? icon,
  Color? iconColor,
  Key? key,
}) {
  return AppPopupMenuItem<T>(
    value: value,
    child: Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null) AppSvgIcon(icon: icon, size: AppSpacing.large, color: iconColor),
        if (icon != null) const SizedBox(width: AppSpacing.small),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppText(text),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.thin),
                AppText(
                  subtitle,
                  variant: AppTextVariant.subtitle,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Returns the global point just below [context]'s render box: its
/// bottom-left corner, or its bottom-centre when [centered] is true.
///
/// Returns `null` when [context] is not laid out as a [RenderBox].
Offset? menuAnchorBelow(BuildContext context, {bool centered = false}) {
  final RenderObject? renderObject = context.findRenderObject();
  if (renderObject is! RenderBox) {
    return null;
  }
  return renderObject.localToGlobal(
    Offset(centered ? renderObject.size.width / AppMath.pair : 0, renderObject.size.height),
  );
}

/// Shows a popup menu of [items] anchored just below [context]'s widget
/// (see [menuAnchorBelow]). Resolves to `null` when dismissed or when the
/// widget is not laid out.
Future<T?> showAppMenuBelow<T>({
  required BuildContext context,
  required List<AppPopupMenuItem<T>> items,
  bool centered = false,
}) async {
  final Offset? anchor = menuAnchorBelow(context, centered: centered);
  if (anchor == null) {
    return null;
  }
  return showAppMenu<T>(
    context: context,
    position: RelativeRect.fromLTRB(anchor.dx, anchor.dy, anchor.dx, anchor.dy),
    items: items,
  );
}

/// Shows a popup menu at the given position, replacing Material [showMenu].
Future<T?> showAppMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<AppPopupMenuItem<T>> items,
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
    builder: (BuildContext dialogContext) {
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
                      children: items.map((AppPopupMenuItem<T> item) {
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
  Widget build(BuildContext context) {
    return AppButton(
      tooltip: tooltip,
      onPressed: () async {
        final T? value = await showAppMenuBelow<T>(
          context: context,
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
