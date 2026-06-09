// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/widgets/app_switch.dart';

/// A row widget replacing Material [ListTile].
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final Widget? leading;
  final VoidCallback? onTap;
  final Widget? subtitle;
  final Widget? title;
  final Widget? trailing;
  @override
  Widget build(final BuildContext context) {
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: AppSpacing.medium,
      ),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: AppSpacing.large),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (title != null)
                  DefaultTextStyle(
                    style: AppTextStyle.bodyBold,
                    child: title!,
                  ),
                if (subtitle != null)
                  DefaultTextStyle(
                    style: AppTextStyle.subtitle,
                    child: subtitle!,
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: row,
        ),
      );
    }
    return row;
  }
}

/// A list tile with a trailing toggle switch, replacing Material [SwitchListTile].
class AppSwitchListTile extends StatelessWidget {
  const AppSwitchListTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final ValueChanged<bool> onChanged;
  final Widget title;
  final bool value;
  @override
  Widget build(final BuildContext context) {
    return AppListTile(
      title: title,
      trailing: AppToggleSwitch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}

/// A toggle switch replacing Material [Switch].
///
/// Delegates to [AppSwitch] to avoid duplicating the switch rendering logic.
class AppToggleSwitch extends StatelessWidget {
  const AppToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ValueChanged<bool> onChanged;
  final bool value;
  @override
  Widget build(final BuildContext context) {
    return AppSwitch(value: value, onChanged: onChanged);
  }
}
