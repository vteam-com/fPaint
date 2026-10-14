import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/nine_grid_selector.dart';
import 'package:fpaint/widgets/size_fields_row.dart';

/// Displays a modal bottom sheet for adjusting canvas settings.
///
/// This function presents a user interface for modifying the canvas size,
/// including width and height inputs, aspect ratio locking, and content alignment
/// options. It allows users to resize the canvas while maintaining the content's
/// positioning within the new dimensions.
///
/// The [context] parameter is the [BuildContext] used to display the modal.
void showCanvasSettings(BuildContext context) {
  // The bottom sheet is pushed onto the app's navigator/overlay, which sits
  // *above* the [InheritedControllerScope] that the editor inserts. Capture the
  // providers from this (in-scope) context so the sheet builder can use them.
  final LayersProvider layers = LayersProvider.of(context, listen: false);
  final ShellProvider shellProvider = ShellProvider.of(context, listen: false);
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  final AppLocalizations l10n = context.l10n;
  CanvasResizePosition canvasResizePosition = layers.canvasResizePosition;

  showSizeSheet(
    context: context,
    title: l10n.canvasSizeTitle,
    initialSize: layers.size,
    initialLockAspectRatio: layers.canvasResizeLockAspectRatio,
    mustBePositiveMessage: l10n.canvasDimensionsMustBePositive,
    widthFieldKey: Keys.canvasSettingsWidthField,
    heightFieldKey: Keys.canvasSettingsHeightField,
    lockButtonKey: Keys.canvasSettingsAspectRatioToggleButton,
    applyButtonKey: Keys.canvasSettingsApplyButton,
    extraBuilder: (BuildContext sheetContext, StateSetter setSheetState) {
      return Column(
        spacing: AppSpacing.medium,
        children: <Widget>[
          AppText(sheetContext.l10n.contentAlignment),
          NineGridSelector(
            selectedPosition: canvasResizePosition,
            onPositionSelected: (CanvasResizePosition newPosition) {
              setSheetState(() => canvasResizePosition = newPosition);
            },
          ),
        ],
      );
    },
    onApply: (Size newSize, bool lockAspectRatio) {
      if (layers.canvasResizeLockAspectRatio != lockAspectRatio) {
        layers.canvasResizeLockAspectRatio = lockAspectRatio;
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
    },
  );
}
