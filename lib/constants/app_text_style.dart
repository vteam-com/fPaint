import 'dart:ui' show FontWeight;

import 'package:flutter/painting.dart' show TextStyle;
import 'package:fpaint/constants/app_colors.dart';
import 'package:fpaint/constants/app_font_size.dart';
import 'package:fpaint/constants/app_strings.dart';

/// Shared text style constants for consistent typography.
///
/// Styles are named by semantic role and follow a 3-tier size system
/// (small / medium / large) combined with normal or bold weight.
class AppTextStyle {
  /// Titles, headings, list tiles — large bold white.
  static const TextStyle title = TextStyle(
    fontFamily: appFontFamily,
    color: AppColors.white,
    fontSize: AppFontSize.large,
    fontWeight: FontWeight.bold,
  );

  /// Editable text fields and form inputs — medium white.
  static const TextStyle input = TextStyle(
    fontFamily: appFontFamily,
    color: AppColors.white,
    fontSize: AppFontSize.medium,
  );

  /// Default body text — white, inherits size from parent.
  static const TextStyle body = TextStyle(
    fontFamily: appFontFamily,
    color: AppColors.white,
  );

  /// Emphasized body text — medium bold, inherits color from parent.
  static const TextStyle bodyBold = TextStyle(
    fontFamily: appFontFamily,
    fontSize: AppFontSize.medium,
    fontWeight: FontWeight.bold,
  );

  /// Tooltips, overlay coordinates — small white.
  static const TextStyle label = TextStyle(
    fontFamily: appFontFamily,
    color: AppColors.white,
    fontSize: AppFontSize.small,
  );

  /// Subtitles, list-tile descriptions, blend-mode hints — medium secondary.
  static const TextStyle subtitle = TextStyle(
    fontFamily: appFontFamily,
    color: AppColors.textSecondary,
    fontSize: AppFontSize.small,
  );

  /// Interactive elements — blue accent color, large font.
  static const TextStyle button = TextStyle(
    fontFamily: appFontFamily,
    color: AppColors.primary,
    fontSize: AppFontSize.medium,
  );
}
