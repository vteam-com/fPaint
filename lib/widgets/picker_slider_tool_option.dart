import 'package:flutter/widgets.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/tool_attribute_widget.dart';

/// The standard tool-option row: an icon button that opens the full picker
/// sheet and, when not [compact], an inline control (usually a slider) beside
/// it.
///
/// Compact panels show only the button, so the inline [inlineControl] is
/// dropped there. Pass [enabled] / [onEnabledChanged] / [enabledToggleKey] to
/// make the row a toggleable option.
class PickerSliderToolOption extends StatelessWidget {
  /// Creates a [PickerSliderToolOption].
  const PickerSliderToolOption({
    super.key,
    required this.name,
    required this.compact,
    required this.icon,
    required this.onOpenPicker,
    this.inlineControl,
    this.buttonKey,
    this.tooltip,
    this.isSelected = false,
    this.enabled,
    this.onEnabledChanged,
    this.enabledToggleKey,
  });

  /// Optional key for the picker button.
  final Key? buttonKey;

  /// Whether the panel is in compact (minimal) mode.
  final bool compact;

  /// Optional active state for toggleable options.
  final bool? enabled;

  /// Optional key for the enable toggle control.
  final Key? enabledToggleKey;

  /// Icon of the picker button.
  final AppIcon icon;

  /// Inline control shown beside the button when not [compact].
  final Widget? inlineControl;

  /// Whether the picker button is drawn selected.
  final bool isSelected;

  /// Label of the option, shown as its tooltip / toggle title.
  final String name;

  /// Optional callback to toggle the option on or off.
  final ValueChanged<bool>? onEnabledChanged;

  /// Opens the full picker sheet.
  final VoidCallback onOpenPicker;

  /// Optional tooltip of the picker button.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return ToolAttributeWidget(
      compact: compact,
      name: name,
      enabled: enabled,
      onEnabledChanged: onEnabledChanged,
      enabledToggleKey: enabledToggleKey,
      childLeft: AppButtonIcon.toolOption(
        key: buttonKey,
        icon: icon,
        compact: compact,
        isSelected: isSelected,
        tooltip: tooltip,
        onPressed: onOpenPicker,
      ),
      childRight: compact ? null : inlineControl,
    );
  }
}
