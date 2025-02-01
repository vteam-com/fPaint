import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/widgets/transparent_background.dart';

class ToolAttributeWidget extends StatelessWidget {
  const ToolAttributeWidget({
    required this.name,
    required this.buttonIcon,
    required this.buttonIconColor,
    required this.onButtonPressed,
    this.child,
    this.transparentPaper = false,
    this.showColorHexValue = false,
    super.key,
  });

  final String name;
  final IconData buttonIcon;
  final Color buttonIconColor;
  final VoidCallback onButtonPressed;
  final Widget? child;
  final bool transparentPaper;
  final bool showColorHexValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: child == null
          ? IconButtonWithBackground(
              name: name,
              buttonIcon: buttonIcon,
              color: buttonIconColor,
              onButtonPressed: onButtonPressed,
              transparentPaper: transparentPaper,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButtonWithBackground(
                  name: name,
                  buttonIcon: buttonIcon,
                  color: buttonIconColor,
                  onButtonPressed: onButtonPressed,
                  transparentPaper: transparentPaper,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: child!,
                ),
              ],
            ),
    );
  }
}

class IconButtonWithBackground extends StatelessWidget {
  const IconButtonWithBackground({
    super.key,
    required this.name,
    required this.buttonIcon,
    required this.color,
    this.transparentPaper = false,
    this.showHexValue = false,
    required this.onButtonPressed,
  });
  final String name;
  final IconData buttonIcon;
  final Color color;
  final bool transparentPaper;
  final bool showHexValue;
  final VoidCallback onButtonPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: transparentPaper ? 90 : 40,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          if (transparentPaper)
            const TransparentPaper(
              patternSize: 4,
            ),
          Positioned(
            top: transparentPaper ? -5 : null,
            child: IconButton(
              icon: Icon(buttonIcon),
              onPressed: onButtonPressed,
              color: color,
              tooltip: name,
            ),
          ),
          if (transparentPaper)
            Positioned(
              bottom: 0,
              child: Container(
                color: color,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  getHexOnMultiline(color),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: contrastColor(color),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
