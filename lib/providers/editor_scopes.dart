import 'package:flutter/widgets.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';

/// Captures the editor controllers in scope at [hostContext] and returns
/// [child] wrapped in [InheritedControllerScope]s that re-provide them.
///
/// Routes and overlays build under the root navigator, which can sit *above*
/// the scopes a host app inserts around the embedded editor. Wrapping their
/// content with this helper lets it resolve the controllers exactly as widgets
/// inside the editor do. Controllers not in scope at [hostContext] are skipped.
Widget reprovideEditorControllerScopes(BuildContext hostContext, Widget child) {
  Widget content = child;
  content = _wrapInScope<UndoProvider>(
    InheritedControllerScope.maybeOf<UndoProvider>(hostContext, listen: false),
    content,
  );
  content = _wrapInScope<LayersProvider>(
    InheritedControllerScope.maybeOf<LayersProvider>(hostContext, listen: false),
    content,
  );
  content = _wrapInScope<AppProvider>(
    InheritedControllerScope.maybeOf<AppProvider>(hostContext, listen: false),
    content,
  );
  content = _wrapInScope<AppPreferences>(
    InheritedControllerScope.maybeOf<AppPreferences>(hostContext, listen: false),
    content,
  );
  content = _wrapInScope<ShellProvider>(
    InheritedControllerScope.maybeOf<ShellProvider>(hostContext, listen: false),
    content,
  );
  return content;
}

/// Wraps [child] in an [InheritedControllerScope] exposing [controller], or
/// returns [child] unchanged when the caller had no such controller in scope.
Widget _wrapInScope<T extends Listenable>(T? controller, Widget child) {
  return controller == null
      ? child
      : InheritedControllerScope<T>(
          controller: controller,
          child: child,
        );
}
