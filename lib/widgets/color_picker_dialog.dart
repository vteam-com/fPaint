import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/color_wheel_selector.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/top_colors.dart';
import 'package:fpaint/widgets/transparent_background.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(logNameColorPicker);

enum _ColorPickerMode {
  sliders,
  wheel,
}

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
  _ColorPickerMode _pickerMode = _ColorPickerMode.sliders;
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

  /// Builds the currently selected picker implementation.
  Widget _buildActivePicker() {
    switch (_pickerMode) {
      case _ColorPickerMode.sliders:
        return ColorSelector(
          color: _currentColor,
          onColorChanged: _setColor,
        );
      case _ColorPickerMode.wheel:
        return ColorWheelSelector(
          color: _currentColor,
          onColorChanged: _setColor,
        );
    }
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
          _buildPickerModeToggle(l10n),

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
                child: _buildActivePicker(),
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
                  onPressed: () => _setColor(color),
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
                  _setColor(color);
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
                    _setColor(color);
                  } on FormatException catch (e) {
                    // Invalid hex color in clipboard; ignore the paste.
                    _log.fine('Ignored invalid pasted hex color', e);
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
                    } on FormatException catch (e) {
                      // Invalid hex color while the user is still typing; ignore.
                      _log.fine('Ignored incomplete hex color input', e);
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

  /// Builds one mode label button in the sliders/wheel toggle row.
  Widget _buildPickerModeLabel({
    required final Key key,
    required final String label,
    required final bool selected,
    required final VoidCallback onPressed,
  }) {
    return AppButton(
      key: key,
      onPressed: onPressed,
      child: SizedBox(
        width: AppLayout.colorPickerModeLabelMinWidth,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyle.bodyBold.copyWith(
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Builds the control that switches between slider and wheel pickers.
  Widget _buildPickerModeToggle(final AppLocalizations l10n) {
    final bool wheelSelected = _pickerMode == _ColorPickerMode.wheel;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: AppSpacing.medium,
      children: <Widget>[
        _buildPickerModeLabel(
          key: Keys.colorPickerModeSlidersButton,
          label: l10n.colorPickerModeSliders,
          selected: !wheelSelected,
          onPressed: () => _setPickerMode(_ColorPickerMode.sliders),
        ),
        AppSwitch(
          key: Keys.colorPickerModeToggle,
          value: wheelSelected,
          onChanged: (final bool useWheel) {
            _setPickerMode(
              useWheel ? _ColorPickerMode.wheel : _ColorPickerMode.sliders,
            );
          },
        ),
        _buildPickerModeLabel(
          key: Keys.colorPickerModeWheelButton,
          label: l10n.colorPickerModeWheel,
          selected: wheelSelected,
          onPressed: () => _setPickerMode(_ColorPickerMode.wheel),
        ),
      ],
    );
  }

  void _setColor(final Color color) {
    setState(() {
      _currentColor = color;
      _hexController.text = colorToHexString(color);
    });
  }

  void _setPickerMode(final _ColorPickerMode mode) {
    if (_pickerMode == mode) {
      return;
    }

    setState(() {
      _pickerMode = mode;
    });
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
