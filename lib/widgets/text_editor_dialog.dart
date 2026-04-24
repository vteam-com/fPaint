import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';

/// Modal dialog used to create a new text object with style settings.
class TextEditorDialog extends StatefulWidget {
  const TextEditorDialog({
    super.key,
    required this.initialFontSize,
    required this.initialColor,
    required this.position,
    required this.onFinished,
  });

  final Color initialColor;

  final double initialFontSize;

  final ValueChanged<TextObject> onFinished;

  final Offset position;

  @override
  State<TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<TextEditorDialog> {
  late TextEditingController _controller;

  late double _fontSize;

  FontStyle _fontStyle = FontStyle.normal;

  FontWeight _fontWeight = FontWeight.normal;

  late Color _textColor;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _fontSize = widget.initialFontSize;
    _textColor = widget.initialColor;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.addText),
      content: SizedBox(
        width: AppLayout.dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Text input field
            AppTextField(
              controller: _controller,
              autofocus: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              hintText: l10n.enterYourTextHere,
              style: TextStyle(
                fontSize: _fontSize,
                color: _textColor,
                fontWeight: _fontWeight,
                fontStyle: _fontStyle,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Font size control
            Text(l10n.fontSizeValue(_fontSize.round())),
            AppSlider(
              value: _fontSize,
              min: AppSpacing.sm + AppMath.pair.toDouble(),
              max: AppLimits.textSizeMax.toDouble(),
              divisions: AppLimits.textSizeDivisions,
              onChanged: (final double value) {
                setState(() {
                  _fontSize = value;
                });
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            // Style controls
            Row(
              children: <Widget>[
                // Bold toggle
                AppIconButton(
                  key: Keys.textEditorBoldButton,
                  icon: AppSvgIcon(
                    icon: AppIcon.formatBold,
                    color: _fontWeight == FontWeight.bold ? AppPalette.blue : AppPalette.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _fontWeight = _fontWeight == FontWeight.bold ? FontWeight.normal : FontWeight.bold;
                    });
                  },
                ),

                // Italic toggle
                AppIconButton(
                  icon: AppSvgIcon(
                    icon: AppIcon.formatItalic,
                    color: _fontStyle == FontStyle.italic ? AppPalette.blue : AppPalette.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _fontStyle = _fontStyle == FontStyle.italic ? FontStyle.normal : FontStyle.italic;
                    });
                  },
                ),

                const Spacer(),

                // Color picker button
                Container(
                  width: AppSpacing.huge,
                  height: AppSpacing.huge,
                  decoration: BoxDecoration(
                    color: _textColor,
                    border: Border.all(color: AppPalette.grey),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: AppIconButton(
                    icon: const AppSvgIcon(icon: AppIcon.colorLens, color: AppPalette.white),
                    onPressed: () async {
                      showColorPicker(
                        context: context,
                        title: l10n.textColor,
                        color: _textColor,
                        onSelectedColor: (final Color color) {
                          setState(() {
                            _textColor = color;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppTextButton(
          child: Text(l10n.cancel),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        AppTextButton(
          child: Text(l10n.addText),
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              widget.onFinished(
                TextObject(
                  text: _controller.text,
                  position: widget.position,
                  color: _textColor,
                  size: _fontSize,
                  fontWeight: _fontWeight,
                  fontStyle: _fontStyle,
                ),
              );
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
