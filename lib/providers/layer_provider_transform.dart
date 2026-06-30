part of 'layer_provider.dart';

/// Canvas rotate/flip transforms for [LayerProvider].
///
/// Extracted into a `part of` extension to keep [LayerProvider] under fCheck's
/// per-class LOC limit (same rationale as [LayerLivePreview]). These rebuild the
/// action stack with transformed copies and return the original GPU textures
/// they replaced, so the caller can dispose them through a reachability check.
extension LayerTransform on LayerProvider {
  /// Rotates all actions and content in the layer by 90 degrees clockwise.
  ///
  /// [oldCanvasSize] is the size of the canvas *before* rotation (width, height will be swapped after this).
  ///
  /// Returns the original GPU textures replaced by rotated copies. The caller
  /// ([LayersProvider.rotateCanvas90Clockwise]) disposes them through a
  /// reachability check, so a texture an undo record can still restore is kept.
  Future<List<ui.Image>> rotate90Clockwise(final Size oldCanvasSize) async {
    final double oldCanvasHeight = oldCanvasSize.height;

    final List<UserActionDrawing> newActionStack = <UserActionDrawing>[];
    final List<ui.Image> replacedImages = <ui.Image>[];

    for (final UserActionDrawing oldAction in actionStack) {
      final List<Offset> newPositions = List<Offset>.from(oldAction.positions);
      for (int i = 0; i < newPositions.length; i++) {
        final Offset oldPos = newPositions[i];
        // Clockwise: (x,y) -> (H_old - y, x)
        newPositions[i] = Offset(oldCanvasHeight - oldPos.dy, oldPos.dx);
      }

      // For image actions the draw origin must be the top-left of the
      // rotated bounding box, not the raw point-transform of the old origin.
      if (oldAction.action == ActionType.image && oldAction.image != null) {
        final double imageWidth = oldAction.image!.width.toDouble();
        final double imageHeight = oldAction.image!.height.toDouble();
        final Offset oldOrigin = oldAction.positions.first;
        // After 90° CW the image dimensions swap: newW = oldH, newH = oldW.
        final Offset newOrigin = Offset(
          oldCanvasHeight - oldOrigin.dy - imageHeight,
          oldOrigin.dx,
        );
        newPositions[0] = newOrigin;
        if (newPositions.length > 1) {
          newPositions[1] = Offset(
            newOrigin.dx + imageHeight,
            newOrigin.dy + imageWidth,
          );
        }
      }

      ui.Path? newPath = oldAction.path;
      if (oldAction.path != null) {
        // Matrix for: x' = H - y; y' = x
        // [ 0 -1 H ]
        // [ 1  0 0 ]
        // [ 0  0 1 ]
        final Matrix4 matrix = Matrix4.identity();
        matrix.setEntry(0, 0, 0.0);
        matrix.setEntry(0, 1, -1.0);
        matrix.setEntry(0, AppMath.triple, oldCanvasHeight); // Translation for x' = H-y
        matrix.setEntry(1, 0, 1.0);
        matrix.setEntry(1, 1, 0.0);
        matrix.setEntry(1, AppMath.triple, 0.0); // No translation for y'
        newPath = oldAction.path!.transform(matrix.storage);
      }

      ui.Path? newClipPath = oldAction.clipPath;
      if (oldAction.clipPath != null) {
        // Apply the same transformation
        final Matrix4 matrix = Matrix4.identity();
        matrix.setEntry(0, 0, 0.0);
        matrix.setEntry(0, 1, -1.0);
        matrix.setEntry(0, AppMath.triple, oldCanvasHeight);
        matrix.setEntry(1, 0, 1.0);
        matrix.setEntry(1, 1, 0.0);
        matrix.setEntry(1, AppMath.triple, 0.0);
        newClipPath = oldAction.clipPath!.transform(matrix.storage);
      }

      ui.Image? newImage = oldAction.image;
      if (oldAction.image != null) {
        final ui.Image originalImage = oldAction.image!;
        final double newImageWidth = originalImage.height.toDouble();
        final double newImageHeight = originalImage.width.toDouble();

        newImage = await renderCanvasImage(
          width: newImageWidth.toInt(),
          height: newImageHeight.toInt(),
          draw: (final ui.Canvas canvas) {
            canvas.translate(newImageWidth / AppMath.pair, newImageHeight / AppMath.pair);
            canvas.rotate(-pi / AppMath.pair); // 90 degrees clockwise (Flutter canvas +angle is CCW)
            canvas.drawImage(
              originalImage,
              Offset(-originalImage.width / AppMath.pair, -originalImage.height / AppMath.pair),
              Paint(),
            );
          },
        );
        replacedImages.add(originalImage);
      }

      // Rotate the text object position: (x,y) -> (H_old - y - textHeight, x)
      TextObject? newTextObject;
      if (oldAction.textObject != null) {
        final TextObject t = oldAction.textObject!;
        final Rect bounds = t.getBounds();
        newTextObject = TextObject(
          text: t.text,
          position: Offset(oldCanvasHeight - t.position.dy - bounds.height, t.position.dx),
          color: t.color,
          size: t.size,
          fontFamily: t.fontFamily,
          fontWeight: t.fontWeight,
          fontStyle: t.fontStyle,
          textAlign: t.textAlign,
        );
      }

      newActionStack.add(
        UserActionDrawing(
          action: oldAction.action,
          positions: newPositions,
          brush: oldAction.brush,
          fillColor: oldAction.fillColor,
          gradient: oldAction.gradient,
          halftoneFill: oldAction.halftoneFill,
          path: newPath,
          image: newImage,
          clipPath: newClipPath,
          textObject: newTextObject,
        ),
      );
    }

    actionStack.clear();
    actionStack.addAll(newActionStack);

    // The layer's own size will be updated by LayersProvider after all layers are processed.
    clearCache();
    return replacedImages;
  }

  /// Flips all actions and content in the layer horizontally (left ↔ right).
  ///
  /// [canvasSize] is the current canvas size used to compute mirrored positions.
  /// Returns the original textures replaced by flipped copies (see [_flip]).
  Future<List<ui.Image>> flipHorizontal(final Size canvasSize) => _flip(canvasSize, isHorizontal: true);

  /// Flips all actions and content in the layer vertically (top ↔ bottom).
  ///
  /// [canvasSize] is the current canvas size used to compute mirrored positions.
  /// Returns the original textures replaced by flipped copies (see [_flip]).
  Future<List<ui.Image>> flipVertical(final Size canvasSize) => _flip(canvasSize, isHorizontal: false);

  /// Shared implementation for flipping layer content on one axis.
  ///
  /// Returns the original GPU textures replaced by flipped copies. The caller
  /// disposes them through a reachability check, so a texture an undo record can
  /// still restore is kept rather than freed.
  Future<List<ui.Image>> _flip(final Size canvasSize, {required final bool isHorizontal}) async {
    final double extent = isHorizontal ? canvasSize.width : canvasSize.height;
    final List<UserActionDrawing> newActionStack = <UserActionDrawing>[];
    final List<ui.Image> replacedImages = <ui.Image>[];

    for (final UserActionDrawing oldAction in actionStack) {
      final List<Offset> newPositions = List<Offset>.from(oldAction.positions);
      for (int i = 0; i < newPositions.length; i++) {
        final Offset oldPos = newPositions[i];
        newPositions[i] = isHorizontal ? Offset(extent - oldPos.dx, oldPos.dy) : Offset(oldPos.dx, extent - oldPos.dy);
      }

      // For image actions the draw origin must be the top-left of the
      // mirrored bounding box, not the raw point-mirror of the old origin.
      if (oldAction.action == ActionType.image && oldAction.image != null) {
        final double imageWidth = oldAction.image!.width.toDouble();
        final double imageHeight = oldAction.image!.height.toDouble();
        final Offset oldOrigin = oldAction.positions.first;
        final Offset newOrigin = isHorizontal
            ? Offset(extent - oldOrigin.dx - imageWidth, oldOrigin.dy)
            : Offset(oldOrigin.dx, extent - oldOrigin.dy - imageHeight);
        newPositions[0] = newOrigin;
        if (newPositions.length > 1) {
          newPositions[1] = Offset(
            newOrigin.dx + imageWidth,
            newOrigin.dy + imageHeight,
          );
        }
      }

      final ui.Path? newPath = _transformPath(oldAction.path, extent, isHorizontal: isHorizontal);
      final ui.Path? newClipPath = _transformPath(oldAction.clipPath, extent, isHorizontal: isHorizontal);
      final ui.Image? newImage = await _flipImage(oldAction.image, isHorizontal: isHorizontal);
      if (oldAction.image != null) {
        replacedImages.add(oldAction.image!);
      }
      final TextObject? newTextObject = _flipTextObject(oldAction.textObject, extent, isHorizontal: isHorizontal);

      newActionStack.add(
        UserActionDrawing(
          action: oldAction.action,
          positions: newPositions,
          brush: oldAction.brush,
          fillColor: oldAction.fillColor,
          gradient: oldAction.gradient,
          halftoneFill: oldAction.halftoneFill,
          path: newPath,
          image: newImage,
          clipPath: newClipPath,
          textObject: newTextObject,
        ),
      );
    }

    actionStack.clear();
    actionStack.addAll(newActionStack);

    clearCache();
    return replacedImages;
  }

  /// Transforms a path for a flip operation.
  ui.Path? _transformPath(
    final ui.Path? path,
    final double extent, {
    required final bool isHorizontal,
  }) {
    if (path == null) {
      return null;
    }
    final Matrix4 matrix = Matrix4.identity();
    if (isHorizontal) {
      matrix.setEntry(0, 0, -1.0);
      matrix.setEntry(0, AppMath.triple, extent);
    } else {
      matrix.setEntry(1, 1, -1.0);
      matrix.setEntry(1, AppMath.triple, extent);
    }
    return path.transform(matrix.storage);
  }

  /// Flips an image horizontally or vertically.
  ///
  /// Delegates to the shared [flipImage] helper.
  Future<ui.Image?> _flipImage(
    final ui.Image? image, {
    required final bool isHorizontal,
  }) async {
    if (image == null) {
      return null;
    }
    return flipImage(image, isHorizontal: isHorizontal);
  }

  /// Flips a text object's position for a flip operation.
  TextObject? _flipTextObject(
    final TextObject? textObject,
    final double extent, {
    required final bool isHorizontal,
  }) {
    if (textObject == null) {
      return null;
    }
    final Rect bounds = textObject.getBounds();
    final Offset oldPos = textObject.position;
    final Offset newPos = isHorizontal
        ? Offset(extent - oldPos.dx - bounds.width, oldPos.dy)
        : Offset(oldPos.dx, extent - oldPos.dy - bounds.height);
    return TextObject(
      text: textObject.text,
      position: newPos,
      color: textObject.color,
      size: textObject.size,
      fontFamily: textObject.fontFamily,
      fontWeight: textObject.fontWeight,
      fontStyle: textObject.fontStyle,
      textAlign: textObject.textAlign,
    );
  }
}
