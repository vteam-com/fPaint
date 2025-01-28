import 'package:flutter/material.dart';
import 'package:fpaint/widgets/transparent_background.dart';

class ToolAttributeWidget extends StatelessWidget {
  const ToolAttributeWidget({
    required this.name,
    required this.buttonIcon,
    required this.buttonIconColor,
    required this.onButtonPressed,
    this.child,
    this.transparentPaper = false,
    super.key,
  });

  final String name;
  final IconData buttonIcon;
  final Color buttonIconColor;
  final VoidCallback onButtonPressed;
  final Widget? child;
  final bool transparentPaper;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: child == null
          ? IconButtonWithBackground(
              name: name,
              buttonIcon: buttonIcon,
              buttonIconColor: buttonIconColor,
              onButtonPressed: onButtonPressed,
              transparentPaper: transparentPaper,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButtonWithBackground(
                  name: name,
                  buttonIcon: buttonIcon,
                  buttonIconColor: buttonIconColor,
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
    required this.buttonIconColor,
    required this.onButtonPressed,
    this.transparentPaper = false,
  });
  final String name;
  final IconData buttonIcon;
  final Color buttonIconColor;
  final VoidCallback onButtonPressed;
  final bool transparentPaper;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          if (transparentPaper)
            const TransparentPaper(
              patternSize: 4,
            ),
          IconButton(
            icon: Icon(buttonIcon),
            onPressed: onButtonPressed,
            color: buttonIconColor,
            tooltip: name,
          ),
        ],
      ),
    );
  }
}
