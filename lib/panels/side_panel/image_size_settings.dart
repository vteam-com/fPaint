import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/material_free.dart';
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
  final TextEditingController widthController = TextEditingController(
    text: layers.size.width.toInt().toString(),
  );
  final TextEditingController heightController = TextEditingController(
    text: layers.size.height.toInt().toString(),
  );
  bool lockAspectRatio = true;

  showAppBottomSheet<void>(
    context: context,
    builder: (BuildContext context) {
      final AppLocalizations l10n = context.l10n;
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.medium,
                children: <Widget>[
                  AppText(
                    l10n.imageSizeTitle,
                    variant: AppTextVariant.title,
                  ),
                  AppText(
                    l10n.imageSizeHint,
                    variant: AppTextVariant.subtitle,
                  ),
                  SizeFieldsRow(
                    widthController: widthController,
                    heightController: heightController,
                    lockAspectRatio: lockAspectRatio,
                    onLockAspectRatioChanged: (bool lock) {
                      setSheetState(() => lockAspectRatio = lock);
                    },
                    widthFieldKey: Keys.imageSizeWidthField,
                    heightFieldKey: Keys.imageSizeHeightField,
                    lockButtonKey: Keys.imageSizeAspectRatioToggleButton,
                  ),
                  AppButtonRow(
                    actions: <Widget>[
                      AppRowPrimaryButton(
                        key: Keys.imageSizeApplyButton,
                        onPressed: () {
                          final Size? newSize = parsePositiveSize(
                            context,
                            widthText: widthController.text,
                            heightText: heightController.text,
                            mustBePositiveMessage: l10n.imageDimensionsMustBePositive,
                          );
                          if (newSize == null) {
                            return;
                          }
                          // Close first: the resample is async and may take a
                          // moment on a large canvas; the sheet has nothing
                          // further to show.
                          Navigator.pop(context);
                          appProvider.resizeImage(
                            newSize.width.toInt(),
                            newSize.height.toInt(),
                          );
                          shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
                          shellProvider.update();
                        },
                        text: l10n.apply,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    widthController.dispose();
    heightController.dispose();
  });
}
