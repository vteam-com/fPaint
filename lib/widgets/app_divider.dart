import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// A horizontal divider line replacing Material [Divider].
class AppDivider extends StatelessWidget {
  const AppDivider({
    super.key,
    this.height = AppStroke.thin,
    this.color = AppColors.divider,
  });
  final Color color;
  final double height;
  @override
  Widget build(final BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ColoredBox(color: color),
    );
  }
}
