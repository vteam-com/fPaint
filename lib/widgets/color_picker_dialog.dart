import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/top_colors.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// A bottom sheet that allows the user to pick a color.
class ColorPickerDialog extends StatefulWidget {
  /// Creates a [ColorPickerDialog].
  const ColorPickerDialog({
    super.key,
    required this.title,
    required this.color,
    required this.onColorChanged,
    this.titleIcon,
  });

  /// The initial color to display in the picker.
  final Color color;

  /// A callback that is called when the user picks a color.
  final ValueChanged<Color> onColorChanged;

  /// The title of the sheet.
  final String title;

  /// Optional icon shown before the title text.
  final Widget? titleIcon;

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
    final LayersProvider layersModel = LayersProvider.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (final bool didPop, _) {
        if (didPop) {
          widget.onColorChanged(_currentColor);
        }
      },
      child: AppBottomSheetContent(
        title: widget.title,
        titleIcon: widget.titleIcon,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildContent(layersModel),
            AppButtonRow(
              actions: _buildActions(),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Cancel / Apply action buttons used by both the dialog and
  /// the small-device layout.
  List<Widget> _buildActions() {
    final AppLocalizations l10n = context.l10n;
    return <Widget>[
      AppRowSecondaryButton(
        onPressed: () => Navigator.of(context).pop(),
        text: l10n.cancel,
      ),
      AppRowPrimaryButton(
        onPressed: () {
          widget.onColorChanged(_currentColor);
          Navigator.of(context).pop();
        },
        text: l10n.apply,
      ),
    ];
  }

  /// Builds the content of the dialog.
  Widget _buildContent(final LayersProvider layers) {
    final AppLocalizations l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.largest,
        children: <Widget>[
          //----------------------------
          // Color preview and selection sliders
          Row(
            spacing: AppSpacing.small,
            children: <Widget>[
              SizedBox(
                height: AppLayout.layerPreviewSize,
                width: AppLayout.layerPreviewSize,
                child: transparentPaperContainer(
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.small),
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

          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: <Widget>[
              for (final Color color in <Color>[
                AppColors.black,
                AppColors.white,
                AppColors.grey,
                AppColors.red,
                AppColors.orange,
                AppColors.yellow,
                AppColors.green,
                AppColors.blue,
                AppColors.purple,
              ])
                ColorPreview(
                  color: color,
                  border: false,
                  minimal: true,
                  onPressed: () {
                    setState(() {
                      _currentColor = color;
                      _hexController.text = colorToHexString(color);
                    });
                  },
                ),
            ],
          ),

          //----------------------------
          // Top colors used in the image
          ListenableBuilder(
            listenable: layers.topColorsListenable,
            builder: (final BuildContext _, final Widget? _) {
              return TopColors(
                colorUsages: layers.topColors,
                onRefresh: layers.evaluateTopColor,
                onColorPicked: (final Color color) {
                  setState(() {
                    _currentColor = color;
                    _hexController.text = colorToHexString(color);
                  });
                },
                showHeader: false,
                autoRefreshOnIdle: true,
                refreshRevision: layers.topColorsRefreshRevision,
              );
            },
          ),

          //----------------------------
          // Hex value edit copy/paste
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AppButtonIcon(
                icon: AppIcon.clipboardPaste,
                onPressed: () async {
                  final ClipboardData? data = await Clipboard.getData(_plainTextMimeType);

                  if (data?.text == null || data!.text is! String) {
                    return;
                  }

                  try {
                    final Color color = getColorFromString(data.text as String);
                    setState(() {
                      _currentColor = color;
                      _hexController.text = colorToHexString(color);
                    });
                  } catch (_) {
                    // Invalid hex color format - silently ignore
                  }
                },
              ),
              SizedBox(
                width: AppLayout.inputFieldWidth,
                child: AppTextField(
                  controller: _hexController,
                  hintText: l10n.hexColor,
                  onChanged: (final String value) {
                    try {
                      final Color color = getColorFromString(value);
                      setState(() {
                        _currentColor = color;
                      });
                    } catch (_) {
                      // Invalid hex color format - silently ignore as user is still typing
                    }
                  },
                ),
              ),
              AppButtonIcon(
                icon: AppIcon.clipboardCopy,
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: colorToHexString(_currentColor),
                    ),
                  );
                  context.showSnackBarMessage(
                    l10n.hexColorCopiedToClipboard,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Displays a color picker bottom sheet with the given title and initial color.
void showColorPicker({
  required final BuildContext context,
  required final String title,
  required final Color color,
  required final ValueChanged<Color> onSelectedColor,
  final Widget? titleIcon,
}) {
  showAppBottomSheet<void>(
    context: context,
    barrierColor: AppColors.transparent,
    builder: (final BuildContext _) {
      return ColorPickerDialog(
        title: title,
        titleIcon: titleIcon ?? AppSvgIcon(icon: AppIcon.waterDrop, color: color),
        color: color,
        onColorChanged: (final Color color) {
          onSelectedColor(color);
        },
      );
    },
  );
}
