import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/providers/editor_scopes.dart';

export 'app_overlay_menu_item.dart';
export 'app_overlay_surface.dart';

/// Shows a general-purpose application overlay with consistent barrier setup.
///
/// Overlay routes build under the root navigator, which can sit *above* the
/// [InheritedControllerScope] widgets a host app inserts around the embedded
/// editor, so the editor controllers in scope at [context] are re-provided
/// around the [builder] subtree via [reprovideEditorControllerScopes]. The
/// [Builder] indirection gives [builder] a context *below* those scopes, so
/// lookups made directly in its body resolve too.
Future<T?> showAppOverlay<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = AppColors.scrim,
}) {
  final Widget content = reprovideEditorControllerScopes(
    context,
    Builder(builder: builder),
  );
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabelDismiss,
    barrierColor: barrierColor,
    pageBuilder:
        (
          BuildContext _,
          Animation<double> _,
          Animation<double> _,
        ) {
          return content;
        },
  );
}
