import 'dart:ui' show Color, TextAlign;

import 'package:flutter/widgets.dart' show StatelessWidget, BuildContext, Text, TextStyle, Widget;
import 'package:fpaint/helpers/constants.dart';

/// Semantic text-style variant for [AppText].
///
/// Each value maps to a corresponding [AppTextStyle] constant, except
/// [inherited] which applies no explicit style and inherits from the nearest
/// [DefaultTextStyle] ancestor.
enum AppTextVariant {
  /// No explicit style — inherits from [DefaultTextStyle].
  inherited,

  /// Page titles, dialog titles, section headings.
  title,

  /// Default body text.
  body,

  /// Emphasized body text.
  bodyBold,

  /// Tooltips, overlay coordinates.
  label,

  /// Subtitles, list-tile descriptions, blend-mode hints.
  subtitle,

  /// Active / selected items.
  accent,

  /// Tappable hyperlinks.
  link,
}

/// A [Text] wrapper that selects its [TextStyle] from [AppTextStyle] by
/// [variant], with an optional [color] override.
///
/// Using [AppText] instead of raw [Text] gives a single control point for
/// typography throughout the app and eliminates most `style.copyWith` calls.
class AppText extends StatelessWidget {
  /// Creates an [AppText].
  const AppText(
    this.data, {
    super.key,
    this.variant = AppTextVariant.inherited,
    this.color,
    this.textAlign,
  });

  /// Optional color override applied on top of the variant's base style.
  final Color? color;

  /// The text to display.
  final String data;

  /// Horizontal alignment of the text within its parent.
  final TextAlign? textAlign;

  /// The semantic style variant to apply.
  final AppTextVariant variant;

  @override
  Widget build(final BuildContext context) {
    TextStyle? style = switch (variant) {
      AppTextVariant.inherited => null,
      AppTextVariant.title => AppTextStyle.title,
      AppTextVariant.body => AppTextStyle.body,
      AppTextVariant.bodyBold => AppTextStyle.bodyBold,
      AppTextVariant.label => AppTextStyle.label,
      AppTextVariant.subtitle => AppTextStyle.subtitle,
      AppTextVariant.accent => AppTextStyle.accent,
      AppTextVariant.link => AppTextStyle.link,
    };

    if (color != null) {
      style = (style ?? const TextStyle()).copyWith(color: color);
    }

    return Text(data, style: style, textAlign: textAlign);
  }
}
