import 'package:flutter/widgets.dart';

/// Generic [InheritedWidget] (non-notifying) wrapper for plain service objects.
/// Use this for singletons that don't notify of changes.
class InheritedScope<T> extends InheritedWidget {
  /// Creates an [InheritedScope].
  const InheritedScope({
    required this.controller,
    required super.child,
    super.key,
  });

  /// The service instance exposed to descendants.
  final T controller;

  /// Retrieves [T] from the widget tree. Throws [FlutterError] if not found.
  static T of<T>(BuildContext context) {
    final T? result = maybeOf<T>(context);
    if (result == null) {
      throw FlutterError('No InheritedScope<$T> found in context');
    }
    return result;
  }

  /// Retrieves [T] from the widget tree, returning null if not found.
  static T? maybeOf<T>(BuildContext context) {
    return context.getInheritedWidgetOfExactType<InheritedScope<T>>()?.controller;
  }

  @override
  bool updateShouldNotify(final InheritedScope<T> oldWidget) => controller != oldWidget.controller;
}
