part of 'app_provider.dart';

/// Undo-history name of an in-place text edit.
const String _textEditRecordName = 'Edit Text';

/// Undo-history name of a text deletion.
const String _textDeleteRecordName = 'Delete Text';

/// Recorded (undoable) edits and deletions of existing text objects.
///
/// New text goes through [AppProvider.recordExecuteDrawingActionToSelectedLayer];
/// these cover the text editor's later changes to an object already on a layer.
extension AppProviderTextEdit on AppProvider {
  /// Replaces [textObject]'s content and style with [updated] as one undo
  /// entry. The object keeps its identity, so the owning action (and an undo of
  /// the original "add text") still refers to it.
  bool updateTextObject(TextObject textObject, TextObject updated) {
    final LayerProvider? layer = this._editableLayerOwning(textObject);
    if (layer == null) {
      return false;
    }
    final TextObject before = textObject.copyWith();
    final TextObject after = updated.copyWith();

    undoProvider.executeAction(
      name: _textEditRecordName,
      forward: () => this._assignText(layer, textObject, after),
      backward: () => this._assignText(layer, textObject, before),
    );
    return true;
  }

  /// Removes the action drawing [textObject] from the selected layer as one
  /// undo entry; undo reinserts it at its original stack position.
  bool deleteTextObject(TextObject textObject) {
    final LayerProvider? layer = this._editableLayerOwning(textObject);
    if (layer == null) {
      return false;
    }
    final int index = layer.actionStack.indexWhere(
      (UserActionDrawing action) => identical(action.textObject, textObject),
    );
    final UserActionDrawing action = layer.actionStack[index];

    undoProvider.executeAction(
      name: _textDeleteRecordName,
      forward: () {
        layer.removeDrawingActionAt(index);
        update();
      },
      backward: () {
        layer.insertDrawingAction(index, action);
        update();
      },
    );
    return true;
  }

  /// The selected layer when it holds [textObject] and accepts edits, else null.
  LayerProvider? _editableLayerOwning(TextObject textObject) {
    if (isSelectedLayerLocked || _undoProvider.isReplaying) {
      return null;
    }
    final LayerProvider layer = layers.selectedLayer;
    final bool owns = layer.actionStack.any(
      (UserActionDrawing action) => identical(action.textObject, textObject),
    );
    return owns ? layer : null;
  }

  /// Copies [source] into [target] and refreshes [layer]'s render.
  void _assignText(LayerProvider layer, TextObject target, TextObject source) {
    target.assignFrom(source);
    layer.hasChanged = true;
    layer.clearCache();
    update();
  }
}
