import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/size_fields_row.dart';

/// Displays a modal bottom sheet for resampling the whole image.
///
/// Unlike the canvas-size sheet (which only changes the bounds and slides the
/// content), applying here scales every layer's pixels to the new dimensions.
/// The aspect-ratio lock starts engaged, which is what a "make it smaller /
/// bigger" resize almost always wants.
void showImageSizeSettings(BuildContext context) {
  // The bottom sheet is pushed onto the app's navigator/overlay, which sits
  // *above* the [InheritedControllerScope] that the editor inserts. Capture the
  // providers from this (in-scope) context so the sheet builder can use them.
  final LayersProvider layers = LayersProvider.of(context, listen: false);
  final ShellProvider shellProvider = ShellProvider.of(context, listen: false);
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  final AppLocalizations l10n = context.l10n;

  showSizeSheet(
    context: context,
    title: l10n.imageSizeTitle,
    hint: l10n.imageSizeHint,
    initialSize: layers.size,
    initialLockAspectRatio: true,
    mustBePositiveMessage: l10n.imageDimensionsMustBePositive,
    widthFieldKey: Keys.imageSizeWidthField,
    heightFieldKey: Keys.imageSizeHeightField,
    lockButtonKey: Keys.imageSizeAspectRatioToggleButton,
    applyButtonKey: Keys.imageSizeApplyButton,
    onApply: (Size newSize, bool _) {
      appProvider.resizeImage(
        newSize.width.toInt(),
        newSize.height.toInt(),
      );
      shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
      shellProvider.update();
    },
  );
}
