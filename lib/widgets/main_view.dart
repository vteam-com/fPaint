import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
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
import 'package:fpaint/widgets/effect_preview_bottom_sheet.dart';
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

    final ShellProvider shellProvider = ShellProvider.of(context);

    return RepaintBoundary(
      key: Keys.mainViewScreenshotBoundary,
      child: ListenableBuilder(
        listenable: shellProvider.canvasFitRequestListenable,
        builder: (final BuildContext _, final Widget? _) => LayoutBuilder(
          builder: (final BuildContext context, final BoxConstraints constraints) {
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

                            if (appProvider.isBrushSizePreviewVisible && appProvider.brushSizePreviewPosition == null)
                              IgnorePointer(
                                child: Center(
                                  child: _BrushSizePreviewOverlay(
                                    diameter: appProvider.brushSizePreviewSize! * appProvider.layers.scale,
                                    color: appProvider.brushSizePreviewColor,
                                  ),
                                ),
                              ),

                            if (appProvider.isBrushSizePreviewVisible && appProvider.brushSizePreviewPosition != null)
                              Positioned(
                                left:
                                    appProvider.brushSizePreviewPosition!.dx -
                                    (appProvider.brushSizePreviewSize! * appProvider.layers.scale) / AppMath.pair,
                                top:
                                    appProvider.brushSizePreviewPosition!.dy -
                                    (appProvider.brushSizePreviewSize! * appProvider.layers.scale) / AppMath.pair,
                                child: IgnorePointer(
                                  child: _BrushSizePreviewOverlay(
                                    diameter: appProvider.brushSizePreviewSize! * appProvider.layers.scale,
                                    color: appProvider.brushSizePreviewColor,
                                  ),
                                ),
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
                                  appProvider.clearSelectionAndRestorePreviousTool();
                                },
                                onEffectSelected: (final SelectionEffect effect, final BuildContext _) async {
                                  if (appProvider.isSelectedLayerLocked) {
                                    _showLockedLayerMessage(appProvider);
                                    return;
                                  }

                                  await startEffectPreviewWithBottomSheet(
                                    context,
                                    appProvider: appProvider,
                                    l10n: context.l10n,
                                    effect: effect,
                                  );
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

                            if (!hasActiveTransformOverlay && appProvider.selectedTextObject != null)
                              const TextEditor(),

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

  void _showLockedLayerMessage(final AppProvider appProvider) {
    showSnackBarIfMounted(
      context,
      context.l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
    );
  }
}

class _BrushSizePreviewOverlay extends StatelessWidget {
  const _BrushSizePreviewOverlay({
    required this.diameter,
    required this.color,
  });
  final Color color;
  final double diameter;
  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      key: Keys.brushSizePreviewOverlay,
      painter: _BrushSizePreviewOverlayPainter(color: color),
      child: SizedBox(
        width: diameter,
        height: diameter,
      ),
    );
  }
}

class _BrushSizePreviewOverlayPainter extends CustomPainter {
  const _BrushSizePreviewOverlayPainter({required this.color});

  final Color color;

  @override
  void paint(final Canvas canvas, final Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.max(
      AppMath.zero.toDouble(),
      (math.min(size.width, size.height) - AppLayout.brushSizePreviewBorderWidth) / AppMath.pair,
    );

    final Paint fillPaint = Paint()
      ..color = color.withAlpha(AppMath.zero)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    final Rect borderRect = Rect.fromCircle(center: center, radius: radius);
    final double circumference = AppMath.pair * AppMath.pi * radius;
    final int segmentCount = math.max(
      AppMath.eight,
      (circumference / AppLayout.brushSizePreviewDashLength).round(),
    );
    final double sweepAngle = (AppMath.pair * AppMath.pi) / segmentCount;

    final Paint blackPaint = Paint()
      ..color = AppColors.black
      ..strokeWidth = AppLayout.brushSizePreviewBorderWidth
      ..style = PaintingStyle.stroke;
    final Paint whitePaint = Paint()
      ..color = AppColors.white
      ..strokeWidth = AppLayout.brushSizePreviewBorderWidth
      ..style = PaintingStyle.stroke;

    for (int index = AppMath.zero; index < segmentCount; index += AppMath.one) {
      canvas.drawArc(
        borderRect,
        index * sweepAngle,
        sweepAngle,
        false,
        index.isEven ? blackPaint : whitePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant final _BrushSizePreviewOverlayPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
