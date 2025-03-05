import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UndoProvider extends ChangeNotifier {
  factory UndoProvider() {
    return _instance;
  }

  UndoProvider._internal();
  static final UndoProvider _instance = UndoProvider._internal();

  static UndoProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) =>
      Provider.of<UndoProvider>(context, listen: listen);

  final List<RecordAction> _undoStack = <RecordAction>[];
  final List<RecordAction> _redoStack = <RecordAction>[];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void recordAction(final RecordAction action) {
    _undoStack.add(action);
    _redoStack.clear(); // Clear redo stack when new action is added
  }

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

  void undo() {
    if (!canUndo) {
      return;
    }

    final RecordAction action = _undoStack.removeLast();
    _redoStack.add(action);
    action.backward();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) {
      return;
    }

    final RecordAction action = _redoStack.removeLast();
    _undoStack.add(action);
    action.forward();
    notifyListeners();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  String getHistoryStringForUndo() {
    return getHistoryString(_undoStack);
  }

  String getHistoryStringForRedo() {
    return getHistoryString(_redoStack);
  }

  String getHistoryString(final List<RecordAction> list) {
    try {
      return this.getActionsAsStrings(list, 20).join('\n');
    } catch (error) {
      debugPrint(error.toString());
      return 'error';
    }
  }

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

  RecordAction? getLastAction() {
    if (_undoStack.isNotEmpty) {
      return _undoStack.last;
    }
    return null;
  }
}

class RecordAction {
  RecordAction({
    required this.name,
    required this.backward,
    required this.forward,
  });

  String name;

  void Function() forward;
  void Function() backward;

  @override
  String toString() {
    return name;
  }
}
