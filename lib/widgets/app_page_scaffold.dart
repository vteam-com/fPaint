import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_scaffold.dart';
import 'package:fpaint/widgets/app_text.dart';

/// A full-screen page: a header bar with a back button and [title], above a
/// centred, scrollable [child] column of fixed [contentWidth].
///
/// Shared by the settings and platforms pages.
class AppPageScaffold extends StatelessWidget {
  /// Creates an [AppPageScaffold].
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.contentWidth,
    required this.child,
  });

  /// Scrollable page content.
  final Widget child;

  /// Width of the centred content column.
  final double contentWidth;

  /// Page title shown in the header bar.
  final String title;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        children: <Widget>[
          DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.surface),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small, vertical: AppSpacing.small),
              child: Row(
                children: <Widget>[
                  AppButtonIcon(
                    icon: AppIcon.arrowLeft,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  AppText(
                    title,
                    variant: AppTextVariant.title,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
