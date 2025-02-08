import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/top_colors.dart';
import 'package:fpaint/widgets/transparent_background.dart';

class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({
    super.key,
    required this.color,
    required this.onColorChanged,
  });
  final Color color;
  final ValueChanged<Color> onColorChanged;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _currentColor;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.color;
    _hexController =
        TextEditingController(text: colorToHexString(_currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.of(context);
    return AlertDialog(
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 20,
            children: [
              //----------------------------
              // Color preview and selection sliders
              Row(
                spacing: 10,
                children: [
                  SizedBox(
                    height: 60,
                    width: 60,
                    child: transparentPaperContainer(
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ColorPreview(
                          colorUsed: ColorUsage(_currentColor, 1),
                          border: false,
                          onPressed: () {},
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ColorSelector(
                      color: _currentColor,
                      onColorChanged: (color) {
                        setState(() {
                          _currentColor = color;
                          _hexController.text = colorToHexString(color);
                        });
                      },
                    ),
                  ),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (Color color in [
                    Colors.red,
                    Colors.orange,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                    Colors.purple,
                  ])
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentColor = color;
                          _hexController.text = colorToHexString(color);
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              //----------------------------
              // Top colors used in the image
              TopColors(
                colorUsages: appModel.topColors,
                onRefresh: () {
                  setState(() {
                    appModel.evaluatTopColor();
                  });
                },
              ),

              //----------------------------
              // Hex value edit copy/paste
              SizedBox(
                width: 200,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.paste),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');

                        try {
                          final color = getColorFromString(
                            data?.text! as String,
                          ); // #FF00FF00
                          setState(() {
                            _currentColor = color;
                            _hexController.text = colorToHexString(color);
                          });
                        } catch (e) {
                          // Invalid hex color format
                        }
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _hexController,
                        decoration: const InputDecoration(
                          labelText: 'Hex Color',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          try {
                            final color = getColorFromString(value);
                            setState(() {
                              _currentColor = color;
                            });
                          } catch (e) {
                            // Invalid hex color format
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: colorToHexString(_currentColor),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hex Color copied to clipboard'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onColorChanged(_currentColor);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
