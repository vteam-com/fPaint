import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/hatch_marks.dart';
import 'package:fpaint/models/hatch_pattern.dart';
import 'package:fpaint/widgets/hatch_marks_picker.dart';
import 'package:fpaint/widgets/hatch_settings_picker.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/tool_attribute_widget.dart';

/// Builds the **Hatching** option row shared by the hatch brush styles and the
/// hatch paint-bucket pattern: an icon button that opens the full settings
/// sheet ([showHatchSettingsPicker]) and, when not [compact], the spacing
/// slider inline — spacing being the knob artists reach for most.
///
/// Pass [enabled] / [onEnabledChanged] / [enabledToggleKey] to make the row a
/// toggleable pattern (the fill); leave them null for an always-on row (a
/// brush whose style already *is* hatching). While disabled, the inline slider
/// is inert but keeps its value, matching the halftone row.
Widget buildHatchToolOption({
  required BuildContext context,
  required bool compact,
  required HatchPattern pattern,
  required ValueChanged<HatchPattern> onChanged,
  required Key sliderKey,
  Key? buttonKey,
  bool? enabled,
  ValueChanged<bool>? onEnabledChanged,
  Key? enabledToggleKey,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool isActive = enabled ?? true;

  return ToolAttributeWidget(
    compact: compact,
    name: l10n.toolHatching,
    enabled: enabled,
    onEnabledChanged: onEnabledChanged,
    enabledToggleKey: enabledToggleKey,
    childLeft: AppButtonIcon(
      key: buttonKey,
      icon: AppIcon.hatch,
      isSelected: enabled ?? false,
      constraints: compact ? const BoxConstraints() : null,
      padding: EdgeInsets.all(compact ? AppSpacing.thin : AppSpacing.small),
      tooltip: l10n.toolHatching,
      onPressed: () {
        showHatchSettingsPicker(
          context: context,
          pattern: pattern,
          onChanged: onChanged,
        );
      },
    ),
    childRight: compact
        ? null
        : AppSlider(
            key: sliderKey,
            label: l10n.hatchSpacing,
            valueLabel: l10n.pixelsValue(pattern.spacing),
            value: pattern.spacing.toDouble(),
            min: AppHatch.minSpacing.toDouble(),
            max: AppHatch.maxSpacing.toDouble(),
            divisions: AppHatch.maxSpacing - AppHatch.minSpacing,
            onChanged: isActive ? (double value) => onChanged(pattern.copyWith(spacing: value.round())) : null,
          ),
  );
}

/// Builds the **Hatch marks** option row for the tapered-marks brush style: an
/// icon button that opens [showHatchMarksPicker] and, when not [compact], the
/// mark length slider inline. Taper and angle live in the sheet.
Widget buildHatchMarksToolOption({
  required BuildContext context,
  required bool compact,
  required HatchMarks marks,
  required ValueChanged<HatchMarks> onChanged,
  required Key buttonKey,
  required Key sliderKey,
}) {
  final AppLocalizations l10n = context.l10n;

  return ToolAttributeWidget(
    compact: compact,
    name: l10n.toolHatchMarks,
    childLeft: AppButtonIcon(
      key: buttonKey,
      icon: AppIcon.hatch,
      constraints: compact ? const BoxConstraints() : null,
      padding: EdgeInsets.all(compact ? AppSpacing.thin : AppSpacing.small),
      tooltip: l10n.toolHatchMarks,
      onPressed: () {
        showHatchMarksPicker(
          context: context,
          marks: marks,
          onChanged: onChanged,
        );
      },
    ),
    childRight: compact
        ? null
        : AppSlider(
            key: sliderKey,
            label: l10n.hatchLength,
            valueLabel: l10n.pixelsValue(marks.length),
            value: marks.length.toDouble(),
            min: AppHatchMarks.minLength.toDouble(),
            max: AppHatchMarks.maxLength.toDouble(),
            divisions: AppHatchMarks.maxLength - AppHatchMarks.minLength,
            onChanged: (double value) => onChanged(marks.copyWith(length: value.round())),
          ),
  );
}
