import 'package:flutter/widget_previews.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/material_free.dart';

/// A widget that displays a tool attribute with a label and a child widget.
class ToolAttributeWidget extends StatelessWidget {
  const ToolAttributeWidget({
    super.key,
    required this.name,
    required this.compact,
    this.childLeft,
    this.childRight,
    this.enabled,
    this.onEnabledChanged,
    this.enabledToggleKey,
  });

  /// The widget to display on the left side of the tool attribute.
  final Widget? childLeft;

  /// The widget to display on the right side of the tool attribute.
  final Widget? childRight;

  /// Whether the widget is in minimal mode.
  final bool compact;

  /// Optional active state for attributes that can be toggled on or off.
  final bool? enabled;

  /// Optional key for the enable toggle control.
  final Key? enabledToggleKey;

  /// The name of the tool attribute.
  final String name;

  /// Optional callback to toggle the attribute on or off.
  final ValueChanged<bool>? onEnabledChanged;

  @override
  Widget build(final BuildContext context) {
    if (compact && childRight == null) {
      if (!_showsEnabledToggle) {
        return SizedBox(
          width: AppLayout.toolbarButtonSize,
          height: AppLayout.toolbarButtonSize,
          child: childLeft!,
        );
      }
      return SizedBox(
        width: AppLayout.toolbarButtonSize,
        height: AppLayout.toolbarButtonSize,
        child: Stack(
          children: <Widget>[
            Center(child: childLeft!),
            Align(
              alignment: Alignment.bottomRight,
              child: Transform.scale(
                scale: AppVisual.half,
                alignment: Alignment.bottomRight,
                child: _buildCompactEnabledToggle(),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(compact ? 0 : AppSpacing.small),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: AppTooltip(
        message: name,
        child: _buildAttributeRow(),
      ),
    );
  }

  /// Builds the main attribute content row, collapsing the secondary control when disabled.
  Widget _buildAttributeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: AppSpacing.medium,
      children: <Widget>[
        // ignore: use_null_aware_elements
        if (childLeft != null) childLeft!,
        if (childRight case final Widget childRightWidget?)
          Expanded(
            child: _buildExpandedContent(childRightWidget),
          ),
        if (_showsEnabledToggle && childRight == null)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Opacity(
                opacity: enabled == true ? AppVisual.full : AppVisual.disabled,
                child: _buildEnabledTitleToggle(),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the compact-mode switch shown when there is no room for a text toggle.
  Widget _buildCompactEnabledToggle() {
    return AppSwitch(
      key: enabledToggleKey,
      value: enabled!,
      onChanged: onEnabledChanged!,
    );
  }

  /// Builds the non-compact title button used to toggle the attribute state.
  Widget _buildEnabledTitleToggle() {
    return AppButtonText(
      key: enabledToggleKey,
      onPressed: () => onEnabledChanged!(!enabled!),
      text: name,
    );
  }

  /// Builds the expanded attribute area, keeping the title toggle in the former caption slot.
  Widget _buildExpandedContent(final Widget childRightWidget) {
    if (!_showsEnabledToggle) {
      return childRightWidget;
    }

    final bool showsExpandedControl = enabled == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.small,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Opacity(
            opacity: enabled == true ? AppVisual.full : AppVisual.disabled,
            child: _buildEnabledTitleToggle(),
          ),
        ),
        AnimatedSwitcher(
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
          child: showsExpandedControl ? childRightWidget : const SizedBox.shrink(),
        ),
      ],
    );
  }

  bool get _showsEnabledToggle => enabled != null && onEnabledChanged != null;
}

/// Widget preview entry for [ToolAttributeWidget].
@Preview(name: 'ToolAttributeWidget')
Widget toolAttributeWidgetPreview() {
  return SizedBox(
    width: AppLayout.sidePanelExpandedMin,
    height: AppLayout.toolAttributeWidgetHeight,
    child: ToolAttributeWidget(
      name: 'Banana Effect',
      compact: false,
      enabled: _toolAttributeWidgetPreviewEnabled,
      onEnabledChanged: _noopEnabledChanged,
      childRight: AppSlider(
        value: _toolAttributeWidgetPreviewHeight,
        valueLabel: '${(_toolAttributeWidgetPreviewHeight * AppLimits.percentMax).toStringAsFixed(0)}%',
        onChanged: (double value) {
          _toolAttributeWidgetPreviewHeight = value;
        },
      ),
    ),
  );
}

double _toolAttributeWidgetPreviewHeight = AppVisual.half;
bool _toolAttributeWidgetPreviewEnabled = true;
void _noopEnabledChanged(final bool value) {
  _toolAttributeWidgetPreviewEnabled != value;
}
