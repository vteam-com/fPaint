import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/widgets/base_picker.dart';
import 'package:fpaint/widgets/slider_picker_state.dart';

/// A widget that allows the user to pick pixel-brush intensity using a slider.
class BrushIntensityPicker extends BasePicker<double> {
  /// Creates a [BrushIntensityPicker].
  const BrushIntensityPicker({
    super.key,
    required super.title,
    required super.value,
    required super.onChanged,
  }) : super(
         min: AppEffects.minIntensity,
         max: AppEffects.maxIntensity,
         divisions: AppLimits.sliderDivisions,
       );

  @override
  BasePickerState<double> createState() => _BrushIntensityPickerState();
}

/// The state for [BrushIntensityPicker].
class _BrushIntensityPickerState extends SliderPickerState<double> {
  @override
  String formatValue(double value) {
    return formatFractionPercent(context.l10n, value);
  }
}

/// Shows a dialog containing a [BrushIntensityPicker].
void showBrushIntensityPicker({
  required BuildContext context,
  required String title,
  required double value,
  required ValueChanged<double> onChanged,
  Widget? titleIcon,
}) {
  final AppLocalizations l10n = context.l10n;
  showPickerDialog(
    context: context,
    title: l10n.selectValue(title),
    titleIcon: titleIcon,
    child: BrushIntensityPicker(
      title: title,
      value: value,
      onChanged: onChanged,
    ),
  );
}
