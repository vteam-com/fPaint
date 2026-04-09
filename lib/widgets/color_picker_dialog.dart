import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/top_colors.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// A dialog that allows the user to pick a color.
class ColorPickerDialog extends StatefulWidget {
  /// Creates a [ColorPickerDialog].
  const ColorPickerDialog({
    super.key,
    required this.title,
    required this.color,
    required this.onColorChanged,
  });

  /// The initial color to display in the picker.
  final Color color;

  /// A callback that is called when the user picks a color.
  final ValueChanged<Color> onColorChanged;

  /// The title of the dialog.
  final String title;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _currentColor;
  late TextEditingController _hexController;
  static const String _plainTextMimeType = 'text/plain';
  @override
  void initState() {
    super.initState();
    _currentColor = widget.color;
    _hexController = TextEditingController(text: colorToHexString(_currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final ShellProvider shellProvider = ShellProvider.of(context);
    final LayersProvider layersModel = LayersProvider.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (final bool didPop, _) {
        if (didPop) {
          widget.onColorChanged(_currentColor);
        }
      },
      child: shellProvider.deviceSizeSmall
          ? Dialog.fullscreen(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.xxl,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
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
              contentPadding: const EdgeInsets.all(AppSpacing.xxxs),
              content: SizedBox(
                width: AppLayout.sliderDialogWidth,
                child: _buildContent(layersModel),
              ),
            ),
    );
  }

  /// Builds the content of the dialog.
  Widget _buildContent(final LayersProvider layers) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xxxl,
        children: <Widget>[
          //----------------------------
          // Color preview and selection sliders
          Row(
            spacing: AppSpacing.xs,
            children: <Widget>[
              SizedBox(
                height: AppLayout.layerPreviewSize,
                width: AppLayout.layerPreviewSize,
                child: transparentPaperContainer(
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: ColorPreview(
                      color: _currentColor,
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
                    width: AppSpacing.huge,
                    height: AppSpacing.huge,
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
                  final ClipboardData? data = await Clipboard.getData(_plainTextMimeType);

                  try {
                    final Color color = getColorFromString(
                      data?.text! as String,
                    ); // #FF00FF00
                    setState(() {
                      _currentColor = color;
                      _hexController.text = colorToHexString(color);
                    });
                  } catch (_) {
                    // Invalid hex color format
                  }
                },
              ),
              SizedBox(
                width: AppLayout.inputFieldWidth,
                child: TextField(
                  controller: _hexController,
                  decoration: InputDecoration(
                    labelText: l10n.hexColor,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (final String value) {
                    try {
                      final Color color = getColorFromString(value);
                      setState(() {
                        _currentColor = color;
                      });
                    } catch (_) {
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
                    SnackBar(
                      content: Text(l10n.hexColorCopiedToClipboard),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(
            height: AppSpacing.huge,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  widget.onColorChanged(_currentColor);
                  Navigator.of(context).pop();
                },
                child: Text(l10n.apply),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Displays a color picker dialog with the given title and initial color.
void showColorPicker({
  required final BuildContext context,
  required final String title,
  required final Color color,
  required final ValueChanged<Color> onSelectedColor,
}) {
  showDialog<dynamic>(
    context: context,
    builder: (final BuildContext _) {
      return ColorPickerDialog(
        title: title,
        color: color,
        onColorChanged: (final Color color) {
          onSelectedColor(color);
        },
      );
    },
  );
}
