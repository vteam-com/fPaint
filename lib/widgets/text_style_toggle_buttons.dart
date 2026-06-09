import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/text_tool_state.dart';
import 'package:fpaint/widgets/app_buttons.dart';

/// Shared bold/italic toggles for text editing and text tool configuration.
class TextStyleToggleButtons extends StatelessWidget {
  const TextStyleToggleButtons({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ValueChanged<TextToolState> onChanged;
  final TextToolState value;

  @override
  Widget build(final BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppButtonIcon(
          key: Keys.textEditorBoldButton,
          icon: AppIcon.formatBold,
          color: value.fontWeight == FontWeight.bold ? AppColors.primary : AppColors.textSecondary,
          onPressed: () {
            onChanged(
              _copyWith(
                fontWeight: value.fontWeight == FontWeight.bold ? FontWeight.normal : FontWeight.bold,
              ),
            );
          },
        ),
        AppButtonIcon(
          key: Keys.textEditorItalicButton,
          icon: AppIcon.formatItalic,
          color: value.fontStyle == FontStyle.italic ? AppColors.primary : AppColors.textSecondary,
          onPressed: () {
            onChanged(
              _copyWith(
                fontStyle: value.fontStyle == FontStyle.italic ? FontStyle.normal : FontStyle.italic,
              ),
            );
          },
        ),
      ],
    );
  }

  /// Returns a copied style state with updated font emphasis values.
  TextToolState _copyWith({
    final FontStyle? fontStyle,
    final FontWeight? fontWeight,
  }) {
    final TextToolState nextValue = value.copy();
    if (fontWeight != null) {
      nextValue.fontWeight = fontWeight;
    }
    if (fontStyle != null) {
      nextValue.fontStyle = fontStyle;
    }
    return nextValue;
  }
}
