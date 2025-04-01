import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Manages the undo and redo stacks for the application.
///
/// This class is a singleton that provides methods for recording actions,
/// undoing actions, and redoing actions. It also provides methods for
/// clearing the undo and redo stacks, and for getting the history of actions.
class UndoProvider extends ChangeNotifier {
  factory UndoProvider() {
    return _instance;
  }

  UndoProvider._internal();
  static final UndoProvider _instance = UndoProvider._internal();

  /// Retrieves the [UndoProvider] instance from the given [BuildContext].
  ///
  /// The [listen] parameter determines whether the widget should rebuild when the
  /// [UndoProvider]'s state changes.
  static UndoProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) =>
      Provider.of<UndoProvider>(context, listen: listen);

  final List<RecordAction> _undoStack = <RecordAction>[];
  final List<RecordAction> _redoStack = <RecordAction>[];

  /// Gets whether there are any actions that can be undone.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Gets whether there are any actions that can be redone.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Records an action to the undo stack.
  void recordAction(final RecordAction action) {
    _undoStack.add(action);
    _redoStack.clear(); // Clear redo stack when new action is added
  }

  /// Executes an action and records it to the undo stack.
  ///
  /// The [name] parameter is the name of the action.
  /// The [backward] parameter is the function to call to undo the action.
  /// The [forward] parameter is the function to call to execute the action.
  RecordAction executeAction({
    required final String name,
    required final void Function() backward,
    required final void Function() forward,
  }) {
    final RecordAction action = RecordAction(
      name: name,
      forward: forward,
      backward: backward,
    );

    recordAction(action);

    // execute the recording
    action.forward();

    notifyListeners();
    return action;
  }

  /// Undoes the last action.
  void undo() {
    if (!canUndo) {
      return;
    }

    final RecordAction action = _undoStack.removeLast();
    _redoStack.add(action);
    action.backward();
    notifyListeners();
  }

  /// Redoes the last action that was undone.
  void redo() {
    if (!canRedo) {
      return;
    }

    final RecordAction action = _redoStack.removeLast();
    _undoStack.add(action);
    action.forward();
    notifyListeners();
  }

  /// Clears the undo and redo stacks.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  /// Gets the history of actions that can be undone as a string.
  String getHistoryStringForUndo() {
    return getHistoryString(_undoStack);
  }

  /// Gets the history of actions that can be redone as a string.
  String getHistoryStringForRedo() {
    return getHistoryString(_redoStack);
  }

  /// Gets the history of actions as a string.
  String getHistoryString(final List<RecordAction> list) {
    try {
      return this.getActionsAsStrings(list, 20).join('\n');
    } catch (error) {
      debugPrint(error.toString());
      return 'error';
    }
  }

  /// Gets the actions as a list of strings.
  List<String> getActionsAsStrings(
    final List<RecordAction> list, [
    final int? numberOfHistoryAction,
  ]) {
    return list
        .take(numberOfHistoryAction ?? list.length)
        .map((final RecordAction action) => action.toString())
        .toList()
        .reversed
        .toList();
  }

  /// Gets the last action that was executed.
  RecordAction? getLastAction() {
    if (_undoStack.isNotEmpty) {
      return _undoStack.last;
    }
    return null;
  }
}

/// Represents an action that can be undone and redone.
class RecordAction {
  RecordAction({
    required this.name,
    required this.backward,
    required this.forward,
  });

  /// The name of the action.
  String name;

  /// The function to call to execute the action.
  void Function() forward;

  /// The function to call to undo the action.
  void Function() backward;

  @override
  String toString() {
    return name;
  }
}
