import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// A card container replacing Material [Card].
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(final BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: child,
    );
  }
}
