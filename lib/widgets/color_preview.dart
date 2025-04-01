import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/widgets/transparent_background.dart';

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
  required final bool minimal,
  required final Color color,
  required final GestureTapCallback onPressed,
}) {
  return SizedBox(
    height: minimal ? 50 : 60,
    width: minimal ? 50 : 60,
    child: transparentPaperContainer(
      radius: minimal ? 10 : 8,
      Padding(
        padding: const EdgeInsets.all(8.0),
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

/// Displays a preview of a color with its hexadecimal components.
///
/// The [ColorPreview] widget displays a square preview of a color, along with its
/// hexadecimal components (alpha, red, green, blue) in a centered text. The
/// preview also includes a white bar on the left side and a black bar on the
/// right side to help visualize the color.
///
/// The widget can be tapped to trigger the provided [onPressed] callback.
/// The tooltip displays the full hexadecimal color code and the usage percentage
/// (if the color usage is less than 100%).
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

  /// The color to preview.
  final Color color;

  /// A callback that is called when the color preview is tapped.
  final GestureTapCallback onPressed;

  /// Whether to display a border around the color preview.
  final bool border;

  /// Whether to display a minimal version of the color preview.
  final bool minimal;

  /// The text to display in the color preview.
  final String? text;

  /// The text to display in the tooltip.
  final String? tooltipText;

  @override
  Widget build(final BuildContext context) {
    final double size = minimal ? 40 : 50;

    final String text = this.text ?? colorToHexString(color);

    return Tooltip(
      message: tooltipText ?? text,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: <Widget>[
              //--------------------------------
              // Rectangle of the final color
              //
              Positioned(
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    border: border ? Border.all(color: Colors.grey) : null,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),

              //--------------------------------
              // Hex color
              //
              if (!minimal)
                Center(
                  child: Text(
                    textAlign: TextAlign.center,
                    text,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      color: color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
