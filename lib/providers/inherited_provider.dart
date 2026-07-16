import 'package:flutter/widgets.dart';

/// Generic [InheritedNotifier] wrapper that exposes a [ChangeNotifier]-based
/// controller to descendants, mirroring the lookup API the app previously
/// got from package:provider's `Provider.of<T>`.
class InheritedControllerScope<T extends Listenable> extends InheritedNotifier<T> {
  const InheritedControllerScope({
    required T controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// The controller instance exposed to descendants.
  T get controller => notifier as T;

  /// Retrieves [T] from the widget tree. If [listen] is true, registers a
  /// dependency that will trigger a rebuild when the controller notifies.
  /// Throws [FlutterError] if not found.
  static T of<T extends Listenable>(BuildContext context, {bool listen = true}) {
    final T? result = _lookup<T>(context, listen: listen);
    if (result == null) {
      throw FlutterError('No InheritedControllerScope<$T> found in context');
    }
    return result;
  }

  /// Retrieves [T] from the widget tree, returning null if not found.
  /// If [listen] is true, registers a dependency on changes.
  static T? maybeOf<T extends Listenable>(BuildContext context, {bool listen = true}) {
    return _lookup<T>(context, listen: listen);
  }

  static T? _lookup<T extends Listenable>(BuildContext context, {required bool listen}) {
    final InheritedControllerScope<T>? scope = listen
        ? context.dependOnInheritedWidgetOfExactType<InheritedControllerScope<T>>()
        : context.getInheritedWidgetOfExactType<InheritedControllerScope<T>>();
    return scope?.controller;
  }
}
