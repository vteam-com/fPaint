import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/transparent_background.dart';

const String _colorPreviewHexPrefix = '#';
const String _colorPreviewLineBreak = '\n';
const String _colorPreviewHexPairSeparator = ' ';

/// Creates a color preview with a transparent paper background.
///
/// This widget combines a [ColorPreview] with a transparent paper background
/// for a visually appealing color selection interface.
///
/// Parameters:
///   [minimal]   Whether to display a minimal version of the color preview.
///   [color]     The color to preview.
///   [onPressed] A callback that is called when the color preview is tapped.
Widget colorPreviewWithTransparentPaper({
  required final Key key,
  required final bool minimal,
  required final Color color,
  required final GestureTapCallback onPressed,
}) {
  return SizedBox(
    key: key,
    height: minimal ? AppLayout.layerPreviewCompactSize : AppLayout.layerPreviewSize,
    width: minimal ? AppLayout.layerPreviewCompactSize : AppLayout.layerPreviewSize,
    child: transparentPaperContainer(
      radius: minimal ? AppRadius.large : AppRadius.medium,
      Padding(
        padding: const EdgeInsets.all(AppSpacing.small),
        child: ColorPreview(
          color: color,
          onPressed: onPressed,
          border: false,
          minimal: minimal,
        ),
      ),
    ),
  );
}

/// Displays a preview of a color inside a soft water-drop silhouette.
///
/// The [ColorPreview] widget keeps the same footprint as the previous square
/// chip, but paints the color inside a proportional droplet path for a more
/// modern look. When the preview is not minimal, the hexadecimal value is drawn
/// in the center of the drop.
///
/// The widget can be tapped to trigger the provided [onPressed] callback.
/// The tooltip displays the configured preview text.
class ColorPreview extends StatelessWidget {
  const ColorPreview({
    super.key,
    required this.color,
    required this.onPressed,
    this.border = true,
    this.minimal = true,
    this.text,
    this.tooltipText,
  });

  /// Legacy compatibility flag retained for existing callers.
  final bool border;

  /// The color to preview.
  final Color color;

  /// Whether to display a minimal version of the color preview.
  final bool minimal;

  /// A callback that is called when the color preview is tapped.
  final GestureTapCallback onPressed;

  /// The text to display in the color preview.
  final String? text;

  /// The text to display in the tooltip.
  final String? tooltipText;

  @override
  Widget build(final BuildContext context) {
    final double size = minimal ? AppSpacing.largest : AppLayout.layerPreviewCompactSize;

    final String text = this.text ?? colorToHexString(color);
    final _ColorPreviewTextLayout? textLayout = _parseColorPreviewTextLayout(text);
    final Color textColor = color.computeLuminance() > AppVisual.half ? AppColors.black : AppColors.white;

    return AppTooltip(
      message: tooltipText ?? text,
      child: GestureDetector(
        key: super.key,
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                Transform.scale(
                  scaleX: _ColorPreviewIconScaleFactors.horizontal,
                  scaleY: _ColorPreviewIconScaleFactors.vertical,
                  child: AppSvgIcon(
                    icon: AppIcon.waterDrop,
                    color: color,
                    size: size,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(AppSpacing.small),
                  child: Center(
                    child: _buildColorPreviewLabel(
                      text: text,
                      textColor: textColor,
                      textLayout: textLayout,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders either the raw preview text or the normalized alpha/RGB stacked layout.
Widget _buildColorPreviewLabel({
  required final String text,
  required final Color textColor,
  required final _ColorPreviewTextLayout? textLayout,
}) {
  final Widget label = textLayout == null
      ? AppText(
          text,
          textAlign: TextAlign.center,
          variant: AppTextVariant.label,
          color: textColor,
        )
      : Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppText(
              textLayout.alpha,
              textAlign: TextAlign.center,
              variant: AppTextVariant.label,
              color: textColor,
            ),
            AppText(
              textLayout.rgb,
              textAlign: TextAlign.center,
              variant: AppTextVariant.label,
              color: textColor,
            ),
          ],
        );

  return FittedBox(
    fit: BoxFit.scaleDown,
    child: label,
  );
}

/// Compensates for the Material-style water-drop icon occupying only part of its 24x24 view-box.
class _ColorPreviewIconScaleFactors {
  static const double iconViewBoxSize = 24.0;
  static const double iconVisibleWidth = 16.0;
  static const double iconVisibleHeight = 19.5;
  static const double horizontal = iconViewBoxSize / iconVisibleWidth;
  static const double vertical = iconViewBoxSize / iconVisibleHeight;
}

class _ColorPreviewTextLayout {
  const _ColorPreviewTextLayout({
    required this.alpha,
    required this.rgb,
  });

  final String alpha;
  final String rgb;
}

/// Normalizes supported hex text variants into an alpha-first display layout.
_ColorPreviewTextLayout? _parseColorPreviewTextLayout(final String text) {
  final String trimmedText = text.trim();
  if (trimmedText.isEmpty) {
    return null;
  }

  final List<String> lines = trimmedText.split(_colorPreviewLineBreak);
  if (lines.length == AppMath.pair) {
    final String firstLine = lines.first.replaceAll(_colorPreviewHexPrefix, '').toUpperCase();
    final String secondLine = lines.last.replaceAll(_colorPreviewHexPrefix, '').toUpperCase();

    if (_isColorPreviewHexPair(firstLine) && _isColorPreviewHexRgb(secondLine)) {
      return _ColorPreviewTextLayout(
        alpha: firstLine,
        rgb: _formatColorPreviewRgbPairs(secondLine),
      );
    }
    if (_isColorPreviewHexRgb(firstLine) && _isColorPreviewHexPair(secondLine)) {
      return _ColorPreviewTextLayout(
        alpha: secondLine,
        rgb: _formatColorPreviewRgbPairs(firstLine),
      );
    }
  }

  final String normalizedText = trimmedText.replaceAll(_colorPreviewHexPrefix, '').toUpperCase();
  if (normalizedText.length != AppLimits.hexArgbLength || !_isColorPreviewHexValue(normalizedText)) {
    return null;
  }

  return _ColorPreviewTextLayout(
    alpha: normalizedText.substring(AppMath.zero, AppMath.pair),
    rgb: _formatColorPreviewRgbPairs(normalizedText.substring(AppMath.pair, AppLimits.hexArgbLength)),
  );
}

String _formatColorPreviewRgbPairs(final String rgbText) {
  return '${rgbText.substring(AppMath.zero, AppMath.pair)}$_colorPreviewHexPairSeparator'
      '${rgbText.substring(AppMath.pair, AppMath.four)}$_colorPreviewHexPairSeparator'
      '${rgbText.substring(AppMath.four, AppMath.six)}';
}

bool _isColorPreviewHexPair(final String value) {
  return value.length == AppMath.pair && _isColorPreviewHexValue(value);
}

bool _isColorPreviewHexRgb(final String value) {
  return value.length == AppLimits.hexRgbLength && _isColorPreviewHexValue(value);
}

bool _isColorPreviewHexValue(final String value) {
  return int.tryParse(value, radix: AppMath.hexRadix) != null;
}
