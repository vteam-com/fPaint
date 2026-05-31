import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/app_provider_tools.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/canvas_panel.dart';
import 'package:fpaint/widgets/effect_intensity_controls.dart';
import 'package:fpaint/widgets/fill_widget.dart';
import 'package:fpaint/widgets/magnifying_eye_dropper.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/selector_widget.dart';
import 'package:fpaint/widgets/text_editor.dart';
import 'package:fpaint/widgets/transform_widget.dart';

/// The main view of the application, which is a stateful widget.
/// This widget is responsible for managing the state of the main view,
/// including handling pointer events and scaling/centering the canvas.
class MainView extends StatefulWidget {
  /// Creates a [MainView].
  const MainView({
    super.key,
  });

  @override
  MainViewState createState() => MainViewState();
}

/// State for [MainView], composing the canvas and editing overlays.
class MainViewState extends State<MainView> {
  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context);

    return RepaintBoundary(
      key: Keys.mainViewScreenshotBoundary,
      child: LayoutBuilder(
        builder: (final BuildContext context, final BoxConstraints constraints) {
          final ShellProvider shellProvider = ShellProvider.of(context);

          // Keep the canvas viewport and every screen-space overlay in the same
          // layout pass so side-panel resizes cannot leave overlays one frame behind.
          if (shellProvider.canvasPlacement == CanvasAutoPlacement.fit) {
            appProvider.canvasFitToContainer(
              containerWidth: constraints.maxWidth,
              containerHeight: constraints.maxHeight,
            );
          }

          return ListenableBuilder(
            listenable: appProvider,
            builder: (final BuildContext _, final Widget? _) {
              return ListenableBuilder(
                listenable: appProvider.viewportRepaintListenable,
                builder: (final BuildContext _, final Widget? _) {
                  return ListenableBuilder(
                    listenable: appProvider.mainViewRepaintListenable,
                    builder: (final BuildContext _, final Widget? _) {
                      final bool hasActiveTransformOverlay = appProvider.hasActiveTransformOverlay;

                      return Stack(
                        children: <Widget>[
                          CanvasGestureHandler(
                            child: _displayCanvas(appProvider),
                          ),

                          if (!hasActiveTransformOverlay &&
                              appProvider.effectPreviewModel.isVisible &&
                              appProvider.effectPreviewModel.previewImage != null &&
                              appProvider.effectPreviewModel.bounds != null)
                            Positioned(
                              left:
                                  appProvider.canvasOffset.dx +
                                  appProvider.effectPreviewModel.bounds!.left * appProvider.layers.scale,
                              top:
                                  appProvider.canvasOffset.dy +
                                  appProvider.effectPreviewModel.bounds!.top * appProvider.layers.scale,
                              child: SizedBox(
                                width: appProvider.effectPreviewModel.bounds!.width * appProvider.layers.scale,
                                height: appProvider.effectPreviewModel.bounds!.height * appProvider.layers.scale,
                                child: RawImage(
                                  image: appProvider.effectPreviewModel.previewImage,
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),

                          //
                          // Color selection from image
                          //
                          if (!hasActiveTransformOverlay && appProvider.eyeDropPositionForBrush != null)
                            _buildEyeDropper(
                              appProvider: appProvider,
                              position: appProvider.eyeDropPositionForBrush!,
                              onColorPicked: (final Color color) {
                                appProvider.brushColor = color;
                              },
                              onDismiss: () {
                                appProvider.eyeDropPositionForBrush = null;
                              },
                            ),

                          if (!hasActiveTransformOverlay && appProvider.eyeDropPositionForFill != null)
                            _buildEyeDropper(
                              appProvider: appProvider,
                              position: appProvider.eyeDropPositionForFill!,
                              onColorPicked: (final Color color) {
                                appProvider.fillColor = color;
                              },
                              onDismiss: () {
                                appProvider.eyeDropPositionForFill = null;
                              },
                            ),

                          //
                          // Selection Widget
                          //
                          if (appProvider.selectorModel.isVisible && !hasActiveTransformOverlay)
                            SelectionRectWidget(
                              path1: appProvider.getPathAdjustToCanvasSizeAndPosition(
                                appProvider.selectorModel.path1,
                              ),
                              path2: appProvider.getPathAdjustToCanvasSizeAndPosition(
                                appProvider.selectorModel.path2,
                              ),
                              enableMoveAndResize:
                                  appProvider.selectedAction == ActionType.selector &&
                                  !appProvider.transformModel.isVisible &&
                                  !appProvider.selectorModel.isDrawing,
                              isDrawing: appProvider.selectorModel.isDrawing,
                              onDrag: (final Offset offset) {
                                appProvider.selectorModel.translate(offset / appProvider.layers.scale);
                                appProvider.repaintMainView();
                              },
                              onDuplicateMove: (final Offset offset, final bool duplicateOnNewLayer) async {
                                if (!duplicateOnNewLayer && appProvider.isSelectedLayerLocked) {
                                  _showLockedLayerMessage(appProvider);
                                  return;
                                }

                                await appProvider.regionDuplicateMove(
                                  offset / appProvider.layers.scale,
                                  onNewLayer: duplicateOnNewLayer,
                                );
                              },
                              onScale: (final double factor) {
                                appProvider.selectorModel.scaleUniform(factor);
                                appProvider.repaintMainView();
                              },
                              onResize: (final NineGridHandle handle, final Offset offset) {
                                appProvider.selectorModel.nindeGridResize(
                                  handle,
                                  offset / appProvider.layers.scale,
                                );
                                appProvider.repaintMainView();
                              },
                              onRotate: (final double angleRadians) {
                                appProvider.selectorModel.rotate(angleRadians);
                                appProvider.repaintMainView();
                              },
                              onToggleTransformMode: () async {
                                if (appProvider.transformModel.isVisible) {
                                  appProvider.cancelTransform();
                                  return;
                                }

                                if (appProvider.isSelectedLayerLocked) {
                                  _showLockedLayerMessage(appProvider);
                                  return;
                                }

                                await appProvider.startTransform();
                              },
                              onCopy: () => appProvider.regionCopy(),
                              onDuplicate: () => appProvider.regionDuplicate(),
                              onCancel: () {
                                appProvider.selectorModel.clear();
                                appProvider.update();
                              },
                              onEffectSelected: (final SelectionEffect effect, final BuildContext _) async {
                                if (appProvider.isSelectedLayerLocked) {
                                  _showLockedLayerMessage(appProvider);
                                  return;
                                }

                                await appProvider.startEffectPreview(effect);
                                if (!mounted) {
                                  return;
                                }
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted || !appProvider.effectPreviewModel.isVisible) {
                                    return;
                                  }
                                  _showEffectPreviewBottomSheet(
                                    context,
                                    appProvider: appProvider,
                                    l10n: context.l10n,
                                  );
                                });
                              },
                            ),

                          //
                          // Fill Widget
                          //
                          if (!hasActiveTransformOverlay && appProvider.fillModel.isVisible)
                            SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: FillWidget(
                                fillModel: appProvider.fillModel,
                                onUpdate: (final GradientPoint _) {
                                  appProvider.updateGradientFill();
                                },
                              ),
                            ),

                          if (!hasActiveTransformOverlay && appProvider.selectedTextObject != null) const TextEditor(),

                          //
                          // Transform overlay (perspective/skew)
                          //
                          if (appProvider.transformModel.isVisible)
                            TransformWidget(
                              model: appProvider.transformModel,
                              canvasOffset: appProvider.canvasOffset,
                              canvasScale: appProvider.layers.scale,
                              onChanged: () => appProvider.repaintMainView(),
                              onConfirm: () async {
                                final TransformSessionSource source = appProvider.transformModel.source;
                                final AppLocalizations l10n = AppLocalizations.of(this.context)!;
                                await appProvider.confirmTransform();
                                if (!mounted || source != TransformSessionSource.duplicateSelection) {
                                  return;
                                }
                                final String targetLayerName = appProvider.layers.selectedLayer.name;
                                final String duplicateMessage = l10n.duplicatedOnLayer(targetLayerName);
                                showSnackBarIfMounted(this.context, duplicateMessage);
                              },
                              onCancel: () => appProvider.cancelTransform(),
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Builds a [MagnifyingEyeDropper] for either brush or fill color picking.
  Widget _buildEyeDropper({
    required final AppProvider appProvider,
    required final Offset position,
    required final ValueChanged<Color> onColorPicked,
    required final VoidCallback onDismiss,
  }) {
    return MagnifyingEyeDropper(
      layers: appProvider.layers,
      pointerPosition: position,
      pixelPosition: appProvider.toCanvas(position),
      onColorPicked: (final Color color) async {
        onColorPicked(color);
        onDismiss();
        appProvider.update();
      },
      onClosed: () {
        onDismiss();
        appProvider.update();
      },
    );
  }

  /// Builds the canvas display widget.
  ///
  /// This method is responsible for creating the widget that displays the
  /// canvas, applying the necessary transformations for panning and scaling.
  Widget _displayCanvas(final AppProvider appProvider) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          colors: <Color>[
            AppColors.grey50,
            AppColors.grey500,
          ],
          stops: <double>[0, 1],
        ),
      ),
      child: SizedBox.expand(
        child: Stack(
          children: <Widget>[
            Positioned(
              left: appProvider.canvasOffset.dx,
              top: appProvider.canvasOffset.dy,
              child: Transform.scale(
                scale: appProvider.layers.scale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: appProvider.layers.width,
                  height: appProvider.layers.height,
                  child: const CanvasPanel(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a transparent-barrier bottom sheet containing [EffectIntensityControls]
  /// so the user can adjust the live effect preview while keeping the canvas visible.
  void _showEffectPreviewBottomSheet(
    final BuildContext context, {
    required final AppProvider appProvider,
    required final AppLocalizations l10n,
  }) {
    showAppBottomSheet<void>(
      context: context,
      barrierColor: AppColors.transparent,
      builder: (final BuildContext sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.small),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.modalSheetContentMaxWidth,
            ),
            child: EffectIntensityControls(
              appProvider: appProvider,
              l10n: l10n,
              sliderKey: Keys.effectIntensityDialogSlider,
              applyButtonKey: Keys.effectIntensityApplyButton,
              cancelButtonKey: Keys.effectIntensityCancelButton,
              onDismiss: () => Navigator.of(sheetCtx).pop(),
            ),
          ),
        ),
      ),
    );
  }

  void _showLockedLayerMessage(final AppProvider appProvider) {
    showSnackBarIfMounted(
      context,
      context.l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
    );
  }
}
