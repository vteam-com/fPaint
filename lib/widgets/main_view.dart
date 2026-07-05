import 'dart:math' as math;
import 'dart:ui' show PathMetric;

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
import 'package:fpaint/widgets/overlay_control_widgets.dart';
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
              listenable: appProvider.mainViewCompositeListenable,
              builder: (final BuildContext _, final Widget? _) {
                final bool hasActiveTransformOverlay = appProvider.hasActiveTransformOverlay;
                // The brush-size ring is a paint-tool affordance; the selector
                // (incl. Edge Detection wand) never paints, so never show it there.
                final bool showBrushSizePreview =
                    appProvider.isBrushSizePreviewVisible && appProvider.selectedAction != ActionType.selector;

                return Stack(
                  children: <Widget>[
                    CanvasGestureHandler(
                      child: _displayCanvas(appProvider),
                    ),

                    // Live smudge/blur gesture marquee (swept brush-width band).
                    // The effect renders once on pointer-up; this is the only
                    // feedback during the drag.
                    if (appProvider.isPixelBrushGestureVisible)
                      Positioned.fill(
                        child: IgnorePointer(
                          // During the drag: the static marquee. On pointer-up,
                          // while the commit generates the image: a processing
                          // shimmer over the same region.
                          child: appProvider.isPixelBrushCommitting
                              ? _PixelBrushProcessingShimmer(
                                  points: appProvider.pixelBrushGesturePoints!,
                                  brushSize: appProvider.pixelBrushGestureSize,
                                  canvasOffset: appProvider.canvasOffset,
                                  scale: appProvider.layers.scale,
                                )
                              : CustomPaint(
                                  painter: _PixelBrushGestureMarqueePainter(
                                    points: appProvider.pixelBrushGesturePoints!,
                                    brushSize: appProvider.pixelBrushGestureSize,
                                    canvasOffset: appProvider.canvasOffset,
                                    scale: appProvider.layers.scale,
                                  ),
                                ),
                        ),
                      ),

                    if (showBrushSizePreview && appProvider.brushSizePreviewPosition == null)
                      IgnorePointer(
                        child: Center(
                          child: _BrushSizePreviewOverlay(
                            diameter: appProvider.brushSizePreviewSize! * appProvider.layers.scale,
                            color: appProvider.brushSizePreviewColor,
                          ),
                        ),
                      ),

                    if (showBrushSizePreview && appProvider.brushSizePreviewPosition != null)
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

                    // Live Edge Detection tolerance readout, tagged near the
                    // finger while dragging to grow/shrink the wand selection.
                    if (appProvider.isWandToleranceHudVisible && appProvider.wandToleranceHudPosition != null)
                      Positioned(
                        left: appProvider.wandToleranceHudPosition!.dx + AppSpacing.large,
                        top: appProvider.wandToleranceHudPosition!.dy - AppSpacing.largest * AppMath.pair,
                        child: IgnorePointer(
                          child: buildOverlayFeedbackBubble(
                            label: '${appProvider.wandToleranceHudTolerance}%',
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
                          appProvider.selectionTranslateByScreenDelta(offset);
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
                          appProvider.selectionScaleUniform(factor);
                        },
                        onResize: (final NineGridHandle handle, final Offset offset) {
                          appProvider.selectionResize(handle, offset);
                        },
                        onRotate: (final double angleRadians) {
                          appProvider.selectionRotate(angleRadians);
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

/// Minimum on-screen width of the swept smudge/blur band (px).
const double _kPixelBrushBandMinWidth = 1.5;

/// Builds the on-screen centre-line path for a smudge/blur gesture: gesture
/// [points] (canvas space) mapped via `canvasOffset + point * scale` — the same
/// transform the canvas panel uses. A single point yields a zero-length segment
/// so a round cap renders the footprint.
Path _pixelBrushStrokePath(final List<Offset> points, final Offset canvasOffset, final double scale) {
  final Path path = Path();
  final Offset first = canvasOffset + (points.first * scale);
  path.moveTo(first.dx, first.dy);
  if (points.length == AppMath.one) {
    path.lineTo(first.dx, first.dy);
  } else {
    for (final Offset point in points.skip(AppMath.one)) {
      final Offset local = canvasOffset + (point * scale);
      path.lineTo(local.dx, local.dy);
    }
  }
  return path;
}

/// Draws the in-progress smudge/blur gesture as a swept brush-width band with a
/// thin outline, in main-view space. Points are in canvas coordinates and are
/// mapped to screen via `canvasOffset + point * scale` — the same transform the
/// canvas panel uses — so the band tracks the pixels that will be affected.
class _PixelBrushGestureMarqueePainter extends CustomPainter {
  const _PixelBrushGestureMarqueePainter({
    required this.points,
    required this.brushSize,
    required this.canvasOffset,
    required this.scale,
  });

  final List<Offset> points;
  final double brushSize;
  final Offset canvasOffset;
  final double scale;

  /// Alpha of the soft dark band edge (0–255) — for definition on any content,
  /// deliberately lighter than a hard outline.
  static const int _edgeAlpha = 70;

  /// Alpha of the translucent light band fill (0–255).
  static const int _fillAlpha = 70;

  /// On-screen width of the thin dashed marquee centre line (px).
  static const double _marqueeLineWidth = 2.0;

  /// Length of each marquee dash and of the gap between successive dashes (px).
  /// The light dashes are phase-shifted by one dash length to fill the gaps, so
  /// the two interleave into a continuous dark/light "marching ants" line.
  static const double _dashLength = 6.0;

  /// Alpha of the dark marquee dashes (0–255).
  static const int _dashDarkAlpha = 160;

  /// Alpha of the light marquee dashes interleaved with the dark ones (0–255).
  static const int _dashLightAlpha = 190;

  @override
  void paint(final Canvas canvas, final Size size) {
    if (points.isEmpty) {
      return;
    }

    final Path path = _pixelBrushStrokePath(points, canvasOffset, scale);
    final double bandWidth = math.max(_kPixelBrushBandMinWidth, brushSize * scale);

    // A soft translucent band showing the affected brush-width area, with a
    // faint edge for definition on any content. A single swept stroke per paint
    // (no per-frame outline math), so cost matches the plain band.
    final Paint edgePaint = Paint()
      ..color = AppColors.black.withAlpha(_edgeAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bandWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, edgePaint);

    final Paint fillPaint = Paint()
      ..color = AppColors.white.withAlpha(_fillAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(AppMath.zero.toDouble(), bandWidth - (AppMath.pair * _kPixelBrushBandMinWidth))
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, fillPaint);

    // A thin dark/light dashed marquee tracing the stroke centre — the "marching
    // ants" cue. Kept thin (not swept at brush width) so dashes never fan out on
    // a dense freehand path; dashing the centre line is cheap (one PathMetrics
    // walk, no per-frame outline computation).
    _drawDashedCentreLine(canvas, path);
  }

  /// Draws [path] as a thin dark/light dashed line: dark dashes occupy the first
  /// half of each `2·_dashLength` period, light dashes the second, so together
  /// they read as a continuous marching-ants marquee.
  void _drawDashedCentreLine(final Canvas canvas, final Path path) {
    final Path darkDashes = _dashPath(path, AppMath.zero.toDouble());
    final Path lightDashes = _dashPath(path, _dashLength);
    canvas.drawPath(darkDashes, _dashPaint(AppColors.black.withAlpha(_dashDarkAlpha)));
    canvas.drawPath(lightDashes, _dashPaint(AppColors.white.withAlpha(_dashLightAlpha)));
  }

  /// Extracts dashes of [_dashLength] (spaced one gap apart) from [source],
  /// starting [phase] px along each contour. A zero-length path (a tap) yields
  /// no dashes, leaving just the footprint band.
  Path _dashPath(final Path source, final double phase) {
    final Path dashed = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = phase;
      while (distance < metric.length) {
        final double end = math.min(distance + _dashLength, metric.length);
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += _dashLength * AppMath.pair;
      }
    }
    return dashed;
  }

  Paint _dashPaint(final Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = _marqueeLineWidth
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(covariant final _PixelBrushGestureMarqueePainter oldDelegate) {
    return !identical(oldDelegate.points, points) ||
        oldDelegate.brushSize != brushSize ||
        oldDelegate.canvasOffset != canvasOffset ||
        oldDelegate.scale != scale;
  }
}

/// Processing overlay shown over the affected region while a smudge/blur commit
/// generates the image: a light "shimmer" sweeps across the swept band (à la
/// iOS Photos Clean Up). Isolated in a [RepaintBoundary] so its per-frame
/// repaint re-runs only this tiny painter and never re-rasterizes the canvas.
class _PixelBrushProcessingShimmer extends StatefulWidget {
  const _PixelBrushProcessingShimmer({
    required this.points,
    required this.brushSize,
    required this.canvasOffset,
    required this.scale,
  });
  final double brushSize;
  final Offset canvasOffset;
  final List<Offset> points;
  final double scale;
  @override
  State<_PixelBrushProcessingShimmer> createState() => _PixelBrushProcessingShimmerState();
}

class _PixelBrushProcessingShimmerState extends State<_PixelBrushProcessingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _sweepPeriod,
  )..repeat();
  static const Duration _sweepPeriod = Duration(milliseconds: 1100);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (final BuildContext _, final Widget? _) => CustomPaint(
          size: Size.infinite,
          painter: _PixelBrushProcessingShimmerPainter(
            points: widget.points,
            brushSize: widget.brushSize,
            canvasOffset: widget.canvasOffset,
            scale: widget.scale,
            progress: _controller.value,
          ),
        ),
      ),
    );
  }
}

/// Paints the smudge/blur processing shimmer: a faint base band over the
/// affected area plus a bright light stripe swept across it by [progress]
/// (0→1, looping). The stripe is masked to the band by using it as the stroke
/// shader, so the shimmer only lights up the pixels being generated.
class _PixelBrushProcessingShimmerPainter extends CustomPainter {
  const _PixelBrushProcessingShimmerPainter({
    required this.points,
    required this.brushSize,
    required this.canvasOffset,
    required this.scale,
    required this.progress,
  });

  final List<Offset> points;
  final double brushSize;
  final Offset canvasOffset;
  final double scale;
  final double progress;

  /// Alpha of the faint base band so the region stays visible between sweeps.
  static const int _baseAlpha = 45;

  /// Alpha of the bright shimmer stripe at its centre.
  static const int _shimmerAlpha = 140;

  /// Width of the sweeping stripe as a fraction of the band's bounding width.
  static const double _stripeFraction = 0.35;

  @override
  void paint(final Canvas canvas, final Size size) {
    if (points.isEmpty) {
      return;
    }

    final Path path = _pixelBrushStrokePath(points, canvasOffset, scale);
    final double bandWidth = math.max(_kPixelBrushBandMinWidth, brushSize * scale);

    // Faint base band so the affected region reads as "busy" between sweeps.
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.white.withAlpha(_baseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = bandWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Bright stripe swept across the band's bounds, masked to the band by using
    // the gradient as the stroke's shader.
    final Rect bounds = path.getBounds().inflate(bandWidth / AppMath.pair);
    if (bounds.width <= AppMath.zero || bounds.height <= AppMath.zero) {
      return;
    }
    final double stripeWidth = math.max(bandWidth, bounds.width * _stripeFraction);
    final double startX = bounds.left - stripeWidth;
    final double stripeX = startX + ((bounds.right - startX) * progress);
    final Rect stripeRect = Rect.fromLTWH(stripeX, bounds.top, stripeWidth, bounds.height);
    final Shader shimmer = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[
        AppColors.white.withAlpha(AppMath.zero),
        AppColors.white.withAlpha(_shimmerAlpha),
        AppColors.white.withAlpha(AppMath.zero),
      ],
    ).createShader(stripeRect);
    canvas.drawPath(
      path,
      Paint()
        ..shader = shimmer
        ..style = PaintingStyle.stroke
        ..strokeWidth = bandWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant final _PixelBrushProcessingShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        !identical(oldDelegate.points, points) ||
        oldDelegate.brushSize != brushSize ||
        oldDelegate.canvasOffset != canvasOffset ||
        oldDelegate.scale != scale;
  }
}
