import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// A simple scaffold replacement using only widgets-layer APIs.
///
/// Provides a dark background with an optional body, replacing the Material
/// [Scaffold] widget.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.backgroundColor = AppColors.background,
  });

  /// Background color (defaults to [AppColors.background]).
  final Color backgroundColor;

  /// The primary content of the scaffold.
  final Widget body;
  @override
  Widget build(final BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: body,
    );
  }
}
