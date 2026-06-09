import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/app_dropdown.dart';
import 'package:fpaint/widgets/app_text.dart';

/// Shared alignment selector for text editing and text tool configuration.
class TextAlignmentDropdown extends StatelessWidget {
  const TextAlignmentDropdown({
    super.key,
    required this.l10n,
    required this.value,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final ValueChanged<TextAlign> onChanged;
  final TextAlign value;

  @override
  Widget build(final BuildContext context) {
    return SizedBox(
      width: AppLayout.inputFieldWidth,
      child: AppDropdown<TextAlign>(
        key: Keys.textEditorAlignmentDropdown,
        value: value,
        items: <AppDropdownItem<TextAlign>>[
          AppDropdownItem<TextAlign>(
            value: TextAlign.left,
            child: AppText(l10n.textAlignLeft),
          ),
          AppDropdownItem<TextAlign>(
            value: TextAlign.center,
            child: AppText(l10n.textAlignCenter),
          ),
          AppDropdownItem<TextAlign>(
            value: TextAlign.right,
            child: AppText(l10n.textAlignRight),
          ),
        ],
        onChanged: (final TextAlign? nextValue) {
          if (nextValue == null) {
            return;
          }
          onChanged(nextValue);
        },
      ),
    );
  }
}
