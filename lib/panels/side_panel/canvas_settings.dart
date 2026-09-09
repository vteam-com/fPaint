import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/nine_grid_selector.dart';
import 'package:fpaint/widgets/size_fields_row.dart';

/// TextEditingController for the width input field.
final TextEditingController widthController = TextEditingController();

/// TextEditingController for the height input field.
final TextEditingController heightController = TextEditingController();

/// Flag to ensure initialization logic is executed only once.
bool initOnce = false;

/// Displays a modal bottom sheet for adjusting canvas settings.
///
/// This function presents a user interface for modifying the canvas size,
/// including width and height inputs, aspect ratio locking, and content alignment
/// options. It allows users to resize the canvas while maintaining the content's
/// positioning within the new dimensions.
///
/// The [context] parameter is the [BuildContext] used to display the modal.
void showCanvasSettings(BuildContext context) {
  initOnce = true;
  // The bottom sheet is pushed onto the app's navigator/overlay, which sits
  // *above* the [InheritedControllerScope] that the editor inserts. Capture the
  // providers from this (in-scope) context so the sheet builder can use them.
  final LayersProvider layers = LayersProvider.of(context, listen: false);
  final ShellProvider shellProvider = ShellProvider.of(context, listen: false);
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  showAppBottomSheet<void>(
    context: context,
    builder: (BuildContext context) {
      final AppLocalizations l10n = context.l10n;
      if (initOnce) {
        widthController.text = layers.size.width.toInt().toString();
        heightController.text = layers.size.height.toInt().toString();
        initOnce = false;
      }

      bool resizeLockAspectRatio = layers.canvasResizeLockAspectRatio;
      CanvasResizePosition canvasResizePosition = layers.canvasResizePosition;

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
                    l10n.canvasSizeTitle,
                    variant: AppTextVariant.title,
                  ),
                  SizeFieldsRow(
                    widthController: widthController,
                    heightController: heightController,
                    lockAspectRatio: resizeLockAspectRatio,
                    onLockAspectRatioChanged: (bool lock) {
                      setSheetState(() => resizeLockAspectRatio = lock);
                    },
                    widthFieldKey: Keys.canvasSettingsWidthField,
                    heightFieldKey: Keys.canvasSettingsHeightField,
                    lockButtonKey: Keys.canvasSettingsAspectRatioToggleButton,
                  ),
                  Column(
                    spacing: AppSpacing.medium,
                    children: <Widget>[
                      AppText(l10n.contentAlignment),
                      NineGridSelector(
                        selectedPosition: canvasResizePosition,
                        onPositionSelected: (CanvasResizePosition newPosition) {
                          setSheetState(() {
                            canvasResizePosition = newPosition;
                          });
                        },
                      ),
                    ],
                  ),
                  AppButtonRow(
                    actions: <Widget>[
                      AppRowPrimaryButton(
                        key: Keys.canvasSettingsApplyButton,
                        onPressed: () {
                          final Size? newSize = parsePositiveSize(
                            context,
                            widthText: widthController.text,
                            heightText: heightController.text,
                            mustBePositiveMessage: l10n.canvasDimensionsMustBePositive,
                          );
                          if (newSize == null) {
                            return;
                          }
                          if (layers.canvasResizeLockAspectRatio != resizeLockAspectRatio) {
                            layers.canvasResizeLockAspectRatio = resizeLockAspectRatio;
                          }
                          if (layers.canvasResizePosition != canvasResizePosition) {
                            layers.canvasResizePosition = canvasResizePosition;
                          }

                          layers.canvasResize(
                            newSize.width.toInt(),
                            newSize.height.toInt(),
                            canvasResizePosition,
                          );

                          shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
                          shellProvider.update();

                          appProvider.update();
                          Navigator.pop(context);
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
  );
}
