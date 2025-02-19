import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/top_colors.dart';
import 'package:fpaint/widgets/transparent_background.dart';

class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({
    super.key,
    this.title = 'Choose a Color',
    required this.color,
    required this.onColorChanged,
  });
  final String title;
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
  Widget build(final BuildContext context) {
    final ShellProvider shellModel = ShellProvider.of(context);
    final LayersProvider layersModel = LayersProvider.of(context);

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        widget.onColorChanged(_currentColor);
        return true;
      },
      child: shellModel.deviceSizeSmall
          ? Dialog.fullscreen(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.start,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _buildContent(layersModel),
                ],
              ),
            )
          : AlertDialog(
              title: Text(widget.title),
              contentPadding: const EdgeInsets.all(2),
              content: SizedBox(
                width: 600,
                child: _buildContent(layersModel),
              ),
            ),
    );
  }

  Widget _buildContent(final LayersProvider layers) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 30,
        children: <Widget>[
          //----------------------------
          // Color preview and selection sliders
          Row(
            spacing: 10,
            children: <Widget>[
              SizedBox(
                height: 60,
                width: 60,
                child: transparentPaperContainer(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ColorPreview(
                      colorUsed: ColorUsage(_currentColor, 1),
                      border: false,
                      minimal: false,
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ColorSelector(
                  color: _currentColor,
                  onColorChanged: (final Color color) {
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
            children: <Widget>[
              for (final Color color in <Color>[
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
            colorUsages: layers.topColors,
            onRefresh: () {
              setState(() {
                layers.evaluatTopColor();
              });
            },
            onColorPicked: (final Color color) {
              setState(() {
                _currentColor = color;
                _hexController.text = colorToHexString(color);
              });
            },
          ),

          //----------------------------
          // Hex value edit copy/paste
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.paste),
                onPressed: () async {
                  final ClipboardData? data =
                      await Clipboard.getData('text/plain');

                  try {
                    final Color color = getColorFromString(
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
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _hexController,
                  decoration: const InputDecoration(
                    labelText: 'Hex Color',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (final String value) {
                    try {
                      final Color color = getColorFromString(value);
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
          const SizedBox(
            height: 40,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
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
          ),
        ],
      ),
    );
  }
}
