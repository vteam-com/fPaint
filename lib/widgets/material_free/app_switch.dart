import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// A toggle switch replacing Material [Switch].
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });
  static const double _thumbInset = 2.0;
  static const double _thumbSize = 20.0;
  static const double _trackHeight = 24.0;
  static const double _trackWidth = 48.0;
  final ValueChanged<bool> onChanged;
  final bool value;
  @override
  Widget build(final BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: _trackWidth,
          height: _trackHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: value ? AppColors.primary : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(_trackHeight / AppMath.pair),
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: const Padding(
                padding: EdgeInsets.all(_thumbInset),
                child: SizedBox(
                  width: _thumbSize,
                  height: _thumbSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppPalette.white,
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
