import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/widgets/base_picker.dart';
import 'package:fpaint/widgets/material_free.dart';

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
class _BrushIntensityPickerState extends BasePickerState<double> {
  @override
  double clampValue(final double value) {
    return value.clamp(widget.min!, widget.max!);
  }

  @override
  Widget buildPickerWidget() {
    return AppSlider(
      value: currentValue,
      min: widget.min!,
      max: widget.max!,
      divisions: widget.divisions,
      onChanged: updateValue,
    );
  }

  @override
  String formatValue(final double value) {
    return '${(value * AppMath.percentScale).round()}%';
  }
}

/// Shows a dialog containing a [BrushIntensityPicker].
void showBrushIntensityPicker({
  required final BuildContext context,
  required final String title,
  required final double value,
  required final ValueChanged<double> onChanged,
  final Widget? titleIcon,
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
