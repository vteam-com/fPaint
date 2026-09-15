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
    this.trailing,
  });

  final EdgeInsetsGeometry padding;
  final String title;

  /// Optional action pinned to the end of the header row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget headerTitle = Opacity(
      opacity: AppVisual.half,
      child: AppText(title, variant: AppTextVariant.title),
    );

    final Widget? trailingAction = trailing;

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (BuildContext _, BoxConstraints constraints) {
          if (!constraints.hasBoundedWidth) {
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: headerTitle,
            );
          }

          // The title takes the slack so the trailing action keeps its full
          // hit target as the panel narrows; below that, the action scales
          // down too rather than overflowing the row.
          return SizedBox(
            width: constraints.maxWidth,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: headerTitle,
                  ),
                ),
                if (trailingAction != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: trailingAction,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
