import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';

/// Opens the text editing flow for the currently selected text object.
class TextEditor extends StatefulWidget {
  const TextEditor({super.key});

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> {
  late final AppProvider appProvider;

  late final TextObject textObject;

  @override
  void initState() {
    super.initState();
    appProvider = AppProvider.of(context);
    textObject = appProvider.selectedTextObject!;

    // Show the edit dialog immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showEditTextDialog();
    });
  }

  @override
  Widget build(final BuildContext context) {
    // Return an empty container since the dialog handles everything
    return const SizedBox.shrink();
  }

  void _deleteText() {
    // Find and remove the text object from the action stack
    final List<UserActionDrawing> actionStack = appProvider.layers.selectedLayer.actionStack;
    actionStack.removeWhere((final UserActionDrawing action) => action.textObject == textObject);

    appProvider.selectedTextObject = null;
    appProvider.layers.selectedLayer.clearCache();
    appProvider.update();
  }

  /// Displays the text editing dialog for the currently selected text object.
  void _showEditTextDialog() {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController controller = TextEditingController(text: textObject.text);
    double fontSize = textObject.size;
    Color textColor = textObject.color;
    FontWeight fontWeight = textObject.fontWeight;
    FontStyle fontStyle = textObject.fontStyle;

    showDialog<void>(
      context: context,
      builder: (final BuildContext _) {
        return StatefulBuilder(
          builder: (final BuildContext context, final StateSetter setState) {
            return AlertDialog(
              title: Text(l10n.editText),
              content: SizedBox(
                width: AppLayout.dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Text input field
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: l10n.enterYourTextHere,
                        border: const OutlineInputBorder(),
                      ),
                      style: TextStyle(
                        fontSize: fontSize,
                        color: textColor,
                        fontWeight: fontWeight,
                        fontStyle: fontStyle,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Font size control
                    Text(l10n.fontSizeValue(fontSize.round())),
                    Slider(
                      value: fontSize,
                      min: AppSpacing.sm + AppMath.pair.toDouble(),
                      max: AppLimits.textSizeMax.toDouble(),
                      divisions: AppLimits.textSizeDivisions,
                      onChanged: (final double value) {
                        setState(() {
                          fontSize = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Style controls
                    Row(
                      children: <Widget>[
                        // Bold toggle
                        IconButton(
                          icon: AppSvgIcon(
                            icon: AppIcon.formatBold,
                            color: fontWeight == FontWeight.bold ? Colors.blue : Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              fontWeight = fontWeight == FontWeight.bold ? FontWeight.normal : FontWeight.bold;
                            });
                          },
                        ),

                        // Italic toggle
                        IconButton(
                          icon: AppSvgIcon(
                            icon: AppIcon.formatItalic,
                            color: fontStyle == FontStyle.italic ? Colors.blue : Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              fontStyle = fontStyle == FontStyle.italic ? FontStyle.normal : FontStyle.italic;
                            });
                          },
                        ),

                        const Spacer(),

                        // Color picker button
                        Container(
                          width: AppSpacing.huge,
                          height: AppSpacing.huge,
                          decoration: BoxDecoration(
                            color: textColor,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: IconButton(
                            icon: const AppSvgIcon(icon: AppIcon.colorLens, color: Colors.white),
                            onPressed: () async {
                              showColorPicker(
                                context: context,
                                title: l10n.textColor,
                                color: textColor,
                                onSelectedColor: (final Color color) {
                                  setState(() {
                                    textColor = color;
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
                TextButton(
                  child: Text(l10n.delete),
                  onPressed: () {
                    _deleteText();
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(l10n.cancel),
                  onPressed: () {
                    appProvider.selectedTextObject = null;
                    appProvider.update();
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(l10n.apply),
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      textObject.text = controller.text;
                      textObject.size = fontSize;
                      textObject.color = textColor;
                      textObject.fontWeight = fontWeight;
                      textObject.fontStyle = fontStyle;
                    } else {
                      _deleteText();
                    }
                    appProvider.selectedTextObject = null;
                    appProvider.update();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
