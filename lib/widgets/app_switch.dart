import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// A toggle switch replacing Material [Switch].
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ValueChanged<bool> onChanged;
  final bool value;
  @override
  Widget build(final BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: AppLayout.switchTrackWidth,
          height: AppLayout.switchTrackHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: value ? AppColors.primary : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppLayout.switchTrackHeight / AppMath.pair),
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: const Padding(
                padding: EdgeInsets.all(AppLayout.switchThumbInset),
                child: SizedBox(
                  width: AppLayout.switchThumbSize,
                  height: AppLayout.switchThumbSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
