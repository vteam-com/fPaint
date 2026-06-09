import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Shared title header used by side-panel sections.
class SidePanelHeader extends StatelessWidget {
  const SidePanelHeader({
    required this.title,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.medium,
      AppSpacing.small,
      AppSpacing.medium,
      AppSpacing.small,
    ),
  });

  final EdgeInsetsGeometry padding;
  final String title;

  @override
  Widget build(final BuildContext context) {
    final Widget headerTitle = Opacity(
      opacity: AppVisual.half,
      child: AppText(title, variant: AppTextVariant.title),
    );

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (final BuildContext _, final BoxConstraints constraints) {
          if (!constraints.hasBoundedWidth) {
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: headerTitle,
            );
          }

          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: headerTitle,
              ),
            ),
          );
        },
      ),
    );
  }
}
