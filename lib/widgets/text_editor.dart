import 'package:flutter/material.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/color_selector.dart';

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

  void _showEditTextDialog() {
    final TextEditingController controller = TextEditingController(text: textObject.text);
    double fontSize = textObject.size;
    Color textColor = textObject.color;
    FontWeight fontWeight = textObject.fontWeight;
    FontStyle fontStyle = textObject.fontStyle;

    showDialog<void>(
      context: context,
      builder: (final BuildContext context) {
        return StatefulBuilder(
          builder: (final BuildContext context, final StateSetter setState) {
            return AlertDialog(
              title: const Text('Edit Text'),
              content: SizedBox(
                width: 400,
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
                      decoration: const InputDecoration(
                        hintText: 'Enter your text here...',
                        border: OutlineInputBorder(),
                      ),
                      style: TextStyle(
                        fontSize: fontSize,
                        color: textColor,
                        fontWeight: fontWeight,
                        fontStyle: fontStyle,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Font size control
                    Text('Font Size: ${fontSize.round()}'),
                    Slider(
                      value: fontSize,
                      min: 8,
                      max: 72,
                      divisions: 32,
                      onChanged: (final double value) {
                        setState(() {
                          fontSize = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Style controls
                    Row(
                      children: <Widget>[
                        // Bold toggle
                        IconButton(
                          icon: Icon(
                            Icons.format_bold,
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
                          icon: Icon(
                            Icons.format_italic,
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: textColor,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.color_lens, color: Colors.white),
                            onPressed: () async {
                              showColorPicker(
                                context: context,
                                title: 'Text Color',
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
                  child: const Text('Delete'),
                  onPressed: () {
                    _deleteText();
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    appProvider.selectedTextObject = null;
                    appProvider.update();
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Apply'),
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

  void _deleteText() {
    // Find and remove the text object from the action stack
    final List<UserActionDrawing> actionStack = appProvider.layers.selectedLayer.actionStack;
    actionStack.removeWhere((final UserActionDrawing action) => action.textObject == textObject);

    appProvider.selectedTextObject = null;
    appProvider.layers.selectedLayer.clearCache();
    appProvider.update();
  }
}
