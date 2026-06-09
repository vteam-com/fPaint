import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/text_tool_state.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/text_formatting_controls.dart';

/// Bottom-sheet content used to create or edit text with shared style controls.
class TextEditorDialog extends StatefulWidget {
  const TextEditorDialog({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.position,
    required this.initialText,
    required this.initialStyle,
    required this.onSubmitted,
    this.onDelete,
  });

  final TextToolState initialStyle;
  final String initialText;
  final VoidCallback? onDelete;
  final ValueChanged<TextObject> onSubmitted;
  final Offset position;
  final String submitLabel;
  final String title;

  @override
  State<TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<TextEditorDialog> {
  late final TextEditingController _controller;
  late TextToolState _style;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _style = widget.initialStyle.copy();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppBottomSheetContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppText(
            widget.title,
            variant: AppTextVariant.title,
          ),
          const SizedBox(height: AppSpacing.large),
          AppTextField(
            controller: _controller,
            autofocus: true,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            hintText: l10n.enterYourTextHere,
            textAlign: _style.textAlign,
            style: AppTextStyle.input.copyWith(
              fontSize: _style.size,
              color: _style.color,
              fontWeight: _style.fontWeight,
              fontStyle: _style.fontStyle,
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          AppSlider(
            label: l10n.fontSizeLabel,
            valueLabel: _style.size.round().toString(),
            value: _style.size,
            min: AppSpacing.small + AppMath.pair.toDouble(),
            max: AppLimits.textSizeMax.toDouble(),
            divisions: AppLimits.textSizeDivisions,
            onChanged: (final double value) {
              setState(() {
                _style.size = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.small),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              TextStyleToggleButtons(
                value: _style,
                onChanged: (final TextToolState value) {
                  setState(() {
                    _style = value;
                  });
                },
              ),
              const SizedBox(width: AppSpacing.medium),
              TextAlignmentDropdown(
                l10n: l10n,
                value: _style.textAlign,
                onChanged: (final TextAlign value) {
                  setState(() {
                    _style.textAlign = value;
                  });
                },
              ),
              const Spacer(),
              Container(
                width: AppSpacing.largest,
                height: AppSpacing.largest,
                decoration: BoxDecoration(
                  color: _style.color,
                  border: Border.all(color: AppColors.grey),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: AppButtonIcon(
                  icon: AppIcon.colorLens,
                  color: AppColors.white,
                  onPressed: () {
                    showColorPicker(
                      context: context,
                      title: l10n.textColor,
                      color: _style.color,
                      onSelectedColor: (final Color color) {
                        setState(() {
                          _style.color = color;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.large),
          AppButtonRow(
            actions: <Widget>[
              if (widget.onDelete != null)
                AppRowDangerButton(
                  text: l10n.delete,
                  onPressed: () {
                    widget.onDelete!.call();
                    Navigator.of(context).pop();
                  },
                ),
              AppRowSecondaryButton(
                text: l10n.cancel,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              AppRowPrimaryButton(
                text: widget.submitLabel,
                onPressed: _submitAndClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Submits the current text (or triggers delete fallback) and closes.
  void _submitAndClose() {
    if (_controller.text.isNotEmpty) {
      widget.onSubmitted(
        _style.buildTextObject(
          text: _controller.text,
          position: widget.position,
        ),
      );
    } else if (widget.onDelete != null) {
      widget.onDelete!.call();
    }
    Navigator.of(context).pop();
  }
}
