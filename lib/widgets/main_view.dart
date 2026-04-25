import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/app_provider_tools.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/canvas_panel.dart';
import 'package:fpaint/widgets/fill_widget.dart';
import 'package:fpaint/widgets/image_placement_widget.dart';
import 'package:fpaint/widgets/magnifying_eye_dropper.dart';
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
    final AppProvider appProvider = AppProvider.of(context, listen: true);

    return RepaintBoundary(
      key: Keys.mainViewScreenshotBoundary,
      child: Stack(
        children: <Widget>[
          LayoutBuilder(
            builder:
                (
                  final BuildContext context,
                  final BoxConstraints constraints,
                ) {
                  final ShellProvider shellProvider = ShellProvider.of(context);

                  // Fit/Center the canvas if requested
                  if (shellProvider.canvasPlacement == CanvasAutoPlacement.fit) {
                    appProvider.canvasFitToContainer(
                      containerWidth: constraints.maxWidth,
                      containerHeight: constraints.maxHeight,
                    );
                  }

                  return CanvasGestureHandler(
                    child: _displayCanvas(appProvider),
                  );
                },
          ),

          //
          // Color selection from image
          //
          if (appProvider.eyeDropPositionForBrush != null)
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

          if (appProvider.eyeDropPositionForFill != null)
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
          if (appProvider.selectorModel.isVisible && !appProvider.transformModel.isVisible)
            SelectionRectWidget(
              path1: appProvider.getPathAdjustToCanvasSizeAndPosition(
                appProvider.selectorModel.path1,
              ),
              path2: appProvider.getPathAdjustToCanvasSizeAndPosition(
                appProvider.selectorModel.path2,
              ),
              enableMoveAndResize:
                  appProvider.selectedAction == ActionType.selector && !appProvider.transformModel.isVisible,
              isDrawing: appProvider.selectorModel.isDrawing,
              onDrag: (final Offset offset) {
                appProvider.selectorModel.translate(offset / appProvider.layers.scale);
                appProvider.update();
              },
              onScale: (final double factor) {
                appProvider.selectorModel.scaleUniform(factor);
                appProvider.update();
              },
              onResize: (final NineGridHandle handle, final Offset offset) {
                appProvider.selectorModel.nindeGridResize(
                  handle,
                  offset / appProvider.layers.scale,
                );
                appProvider.update();
              },
              onRotate: (final double angleRadians) {
                appProvider.selectorModel.rotate(angleRadians);
                appProvider.update();
              },
              onToggleTransformMode: () async {
                if (appProvider.transformModel.isVisible) {
                  appProvider.cancelTransform();
                  return;
                }

                await appProvider.startTransform();
              },
              onCopy: () => appProvider.regionCopy(),
              onDuplicate: () => appProvider.regionDuplicate(),
              onApplyEffect: (final SelectionEffect effect, final double strength) =>
                  appProvider.applyEffect(effect, strength: strength),
            ),

          //
          // Fill Widget
          //
          if (appProvider.fillModel.isVisible)
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

          if (appProvider.selectedTextObject != null) const TextEditor(),

          //
          // Image placement overlay (paste with interactive transform)
          //
          if (appProvider.imagePlacementModel.isVisible)
            ImagePlacementWidget(
              model: appProvider.imagePlacementModel,
              canvasOffset: appProvider.canvasOffset,
              canvasScale: appProvider.layers.scale,
              onChanged: () => appProvider.update(),
              onConfirm: () => appProvider.confirmImagePlacement(),
              onCancel: () => appProvider.cancelImagePlacement(),
            ),

          //
          // Transform overlay (perspective/skew)
          //
          if (appProvider.transformModel.isVisible)
            TransformWidget(
              model: appProvider.transformModel,
              canvasOffset: appProvider.canvasOffset,
              canvasScale: appProvider.layers.scale,
              onChanged: () => appProvider.update(),
              onConfirm: () => appProvider.confirmTransform(),
              onCancel: () => appProvider.cancelTransform(),
            ),
        ],
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
            AppPalette.grey50,
            AppPalette.grey500,
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
}
