import 'package:flutter/material.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/widgets/color_selector.dart';

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
    return AlertDialog(
      title: const Text('Add Text'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Text input field
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'Enter your text here...',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(
                fontSize: _fontSize,
                color: _textColor,
                fontWeight: _fontWeight,
                fontStyle: _fontStyle,
              ),
            ),
            const SizedBox(height: 20),

            // Font size control
            Text('Font Size: ${_fontSize.round()}'),
            Slider(
              value: _fontSize,
              min: 8,
              max: 72,
              divisions: 32,
              onChanged: (final double value) {
                setState(() {
                  _fontSize = value;
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
                    color: _fontWeight == FontWeight.bold ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _fontWeight = _fontWeight == FontWeight.bold ? FontWeight.normal : FontWeight.bold;
                    });
                  },
                ),

                // Italic toggle
                IconButton(
                  icon: Icon(
                    Icons.format_italic,
                    color: _fontStyle == FontStyle.italic ? Colors.blue : Colors.grey,
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _textColor,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.color_lens, color: Colors.white),
                    onPressed: () async {
                      showColorPicker(
                        context: context,
                        title: 'Text Color',
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
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Add Text'),
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
