import 'package:flutter/material.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/fill_widget.dart';
import 'package:fpaint/widgets/magnifying_eye_dropper.dart';
import 'package:fpaint/widgets/selector_widget.dart';
import 'package:fpaint/widgets/text_editor.dart';

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

class MainViewState extends State<MainView> {
  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: true);

    return Stack(
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
          MagnifyingEyeDropper(
            layers: appProvider.layers,
            pointerPosition: appProvider.eyeDropPositionForBrush!,
            pixelPosition: appProvider.toCanvas(appProvider.eyeDropPositionForBrush!),
            onColorPicked: (final Color color) async {
              appProvider.brushColor = color;
              appProvider.eyeDropPositionForBrush = null;
              appProvider.update();
            },
            onClosed: () {
              appProvider.eyeDropPositionForBrush = null;
              appProvider.update();
            },
          ),

        if (appProvider.eyeDropPositionForFill != null)
          MagnifyingEyeDropper(
            layers: appProvider.layers,
            pointerPosition: appProvider.eyeDropPositionForFill!,
            pixelPosition: appProvider.toCanvas(appProvider.eyeDropPositionForFill!),
            onColorPicked: (final Color color) async {
              appProvider.fillColor = color;
              appProvider.eyeDropPositionForFill = null;
              appProvider.update();
            },
            onClosed: () {
              appProvider.eyeDropPositionForFill = null;
              appProvider.update();
            },
          ),

        //
        // Selection Widget
        //
        if (appProvider.selectorModel.isVisible)
          SelectionRectWidget(
            path1: appProvider.getPathAdjustToCanvasSizeAndPosition(
              appProvider.selectorModel.path1,
            ),
            path2: appProvider.getPathAdjustToCanvasSizeAndPosition(
              appProvider.selectorModel.path2,
            ),
            enableMoveAndResize: appProvider.selectedAction == ActionType.selector,
            onDrag: (final Offset offset) {
              appProvider.selectorModel.translate(offset);
              appProvider.update();
            },
            onResize: (final NineGridHandle handle, final Offset offset) {
              appProvider.selectorModel.nindeGridResize(handle, offset);
              appProvider.update();
            },
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
              onUpdate: (final GradientPoint point) {
                appProvider.updateGradientFill();
              },
            ),
          ),

        if (appProvider.selectedTextObject != null) const TextEditor(),
      ],
    );
  }

  /// Builds the canvas display widget.
  ///
  /// This method is responsible for creating the widget that displays the
  /// canvas, applying the necessary transformations for panning and scaling.
  Widget _displayCanvas(final AppProvider appProvider) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          colors: <Color>[
            Colors.grey.shade50,
            Colors.grey.shade500,
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
