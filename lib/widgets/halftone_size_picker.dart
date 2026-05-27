// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/base_picker.dart';
import 'package:fpaint/widgets/material_free.dart';

/// A widget that allows the user to pick the halftone dot-size percentage.
class HalftoneSizePicker extends BasePicker<int> {
  /// Creates a [HalftoneSizePicker].
  const HalftoneSizePicker({
    super.key,
    required super.title,
    required super.value,
    required super.onChanged,
  }) : super(
         min: AppMath.zero,
         max: AppLimits.percentMax,
         divisions: AppLimits.sliderDivisions,
       );

  @override
  HalftoneSizePickerState createState() => HalftoneSizePickerState();
}

/// The state for [HalftoneSizePicker].
class HalftoneSizePickerState extends BasePickerState<int> {
  @override
  int clampValue(final int value) {
    return value.clamp(AppMath.zero, AppLimits.percentMax);
  }

  @override
  Widget buildPickerWidget() {
    return AppSlider(
      value: currentValue.toDouble(),
      min: AppMath.zero.toDouble(),
      max: AppLimits.percentMax.toDouble(),
      divisions: AppLimits.sliderDivisions,
      onChanged: (final double value) => updateValue(value.toInt()),
    );
  }

  @override
  String formatValue(final int value) {
    final AppLocalizations l10n = context.l10n;
    return l10n.percentageValue(value);
  }
}

/// Shows a dialog containing a [HalftoneSizePicker].
void showHalftoneSizePicker({
  required final BuildContext context,
  required final int value,
  required final bool enabled,
  required final ValueChanged<int> onChanged,
  required final ValueChanged<bool> onEnabledChanged,
}) {
  final AppLocalizations l10n = context.l10n;
  int currentValue = value;
  bool isEnabled = enabled;

  showAppBottomSheet<void>(
    context: context,
    barrierColor: AppColors.transparent,
    builder: (final BuildContext _) {
      return StatefulBuilder(
        builder: (final BuildContext _, final void Function(void Function()) setSheetState) {
          return AppBottomSheetContent(
            title: l10n.toolHalftone,
            titleIcon: const AppSvgIcon(icon: AppIcon.halftone),
            titleTrailing: AppSwitch(
              key: Keys.toolFillHalftoneToggle,
              value: isEnabled,
              onChanged: (final bool nextValue) {
                setSheetState(() {
                  isEnabled = nextValue;
                });
                onEnabledChanged(nextValue);
              },
            ),
            child: AnimatedSwitcher(
              duration: AppDefaults.toolPanelRevealAnimationDuration,
              reverseDuration: AppDefaults.toolPanelRevealAnimationDuration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (final Widget child, final Animation<double> animation) {
                return ClipRect(
                  child: FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      child: child,
                    ),
                  ),
                );
              },
              child: isEnabled
                  ? HalftoneSizePicker(
                      key: const ValueKey<String>('halftone_size_picker_enabled'),
                      title: l10n.toolHalftone,
                      value: currentValue,
                      onChanged: (final int newValue) {
                        currentValue = newValue;
                        onChanged(newValue);
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          );
        },
      );
    },
  );
}
