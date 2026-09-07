// ignore: fcheck_one_class_per_file

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:logging/logging.dart';

/// Callback invoked with [RecordAction]s that are permanently dropped from
/// history (redo cleared, trimmed, or a full clear). Owners use it to dispose
/// the GPU textures those records would otherwise have resurrected, once no
/// surviving owner still references them.
typedef RecordsDroppedCallback = void Function(List<RecordAction> dropped);

const String _errorFallback = 'error';

/// Manages the undo and redo stacks for the application.
///
/// This class is a singleton that provides methods for recording actions,
/// undoing actions, and redoing actions. It also provides methods for
/// clearing the undo and redo stacks, and for getting the history of actions.
class UndoProvider extends ChangeNotifier {
  UndoProvider();

  static final Logger _log = Logger(logNameUndoProvider);

  /// Largest number of records retained in the undo stack. Beyond this the
  /// oldest records are evicted (see [recordAction]). Overridable for tests.
  int maxUndoHistory = AppLimits.maxUndoHistory;

  /// Retrieves the [UndoProvider] instance from the given [BuildContext].
  ///
  /// The [listen] parameter determines whether the widget should rebuild when the
  /// [UndoProvider]'s state changes.
  static UndoProvider of(
    BuildContext context, {
    bool listen = false,
  }) => InheritedControllerScope.of<UndoProvider>(context, listen: listen);

  final List<RecordAction> _undoStack = <RecordAction>[];
  final List<RecordAction> _redoStack = <RecordAction>[];

  /// True while an asynchronous apply or replay is in flight. Re-entrant
  /// undo/redo calls and new async actions are dropped so a second request
  /// cannot interleave with a half-applied one (for example a canvas rotation
  /// still re-rasterizing every layer).
  bool _isReplaying = false;

  /// Whether an asynchronous apply/replay is in flight. Guarded mutation
  /// entry points (drawing, rotate/flip) drop their input while this is true
  /// rather than interleave with the half-applied record.
  bool get isReplaying => _isReplaying;

  /// Invoked whenever records leave history for good. The owner disposes any
  /// GPU textures the dropped records retained that nothing else references.
  RecordsDroppedCallback? onRecordsDropped;

  /// All GPU textures still resurrectable by some record in either stack.
  ///
  /// Used by owners to decide whether a candidate image is safe to dispose: an
  /// image present here can still be restored by an undo/redo and must be kept.
  Iterable<ui.Image> get liveRetainedImages =>
      _undoStack.followedBy(_redoStack).expand((RecordAction r) => r.retainedImages);

  /// Gets whether there are any actions that can be undone.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Gets whether there are any actions that can be redone.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Records an action to the undo stack.
  void recordAction(RecordAction action) {
    _undoStack.add(action);
    // Enforce the global cap: evict the oldest records beyond the limit. Their
    // content stays on the canvas (it just can no longer be undone); detach them
    // first, then report so the reachability check frees any textures they were
    // the last owner of.
    if (_undoStack.length > maxUndoHistory) {
      final int overflow = _undoStack.length - maxUndoHistory;
      final List<RecordAction> evicted = _undoStack.sublist(0, overflow);
      _undoStack.removeRange(0, overflow);
      _dropRecords(evicted);
    }
    if (_redoStack.isEmpty) {
      return;
    }
    // The redo records are unreachable once a new action is recorded. Detach
    // and clear them first, then report so reachability excludes them.
    final List<RecordAction> dropped = List<RecordAction>.of(_redoStack);
    _redoStack.clear();
    _dropRecords(dropped);
  }

  /// Executes an action and records it to the undo stack.
  ///
  /// The [name] parameter is the name of the action.
  /// The [backward] parameter is the function to call to undo the action.
  /// The [forward] parameter is the function to call to execute the action.
  /// The [retainedImages] are GPU textures the action's closures can resurrect
  /// on undo/redo; the owner disposes them once this record leaves history.
  RecordAction executeAction({
    required String name,
    required void Function() backward,
    required void Function() forward,
    List<ui.Image> retainedImages = const <ui.Image>[],
  }) {
    final RecordAction action = RecordAction(
      name: name,
      forward: forward,
      backward: backward,
      retainedImages: retainedImages,
    );

    recordAction(action);

    // execute the recording
    action.forward();

    notifyListeners();
    return action;
  }

  /// Executes an asynchronous action and records it to the undo stack.
  ///
  /// Like [executeAction], but the closures may be asynchronous (for example a
  /// canvas rotation re-rasterizing every layer). [forward] is awaited so the
  /// returned future completes only once the action is fully applied; undo and
  /// redo are blocked (via [isReplaying]) until then, and [undo]/[redo] await
  /// the closures when replaying the record. Returns null — recording and
  /// executing nothing — when another async apply/replay is already in flight,
  /// so two multi-second mutations can never interleave.
  Future<RecordAction?> executeActionAsync({
    required String name,
    required FutureOr<void> Function() backward,
    required FutureOr<void> Function() forward,
    List<ui.Image> retainedImages = const <ui.Image>[],
  }) async {
    if (_isReplaying) {
      return null;
    }

    final RecordAction action = RecordAction(
      name: name,
      forward: forward,
      backward: backward,
      retainedImages: retainedImages,
    );

    // The record is on the stack before forward runs, so hold the replay guard
    // across the apply: without it a Cmd+Z during a multi-second rotate would
    // run backward() interleaved with the still-applying forward.
    recordAction(action);
    _isReplaying = true;
    try {
      await action.forward();
    } finally {
      _isReplaying = false;
    }
    notifyListeners();
    return action;
  }

  /// Undoes the last action.
  ///
  /// Completes once the action is fully reverted. A synchronous record is
  /// reverted before this returns (no suspension); an asynchronous one is
  /// awaited, and re-entrant calls during the replay are ignored.
  Future<void> undo() async {
    if (!canUndo || _isReplaying) {
      return;
    }

    final RecordAction action = _undoStack.removeLast();
    _redoStack.add(action);
    await _replayRecordClosure(action.backward);
  }

  /// Redoes the last action that was undone.
  ///
  /// Completes once the action is fully re-applied; see [undo] for the
  /// synchronous/asynchronous replay contract.
  Future<void> redo() async {
    if (!canRedo || _isReplaying) {
      return;
    }

    final RecordAction action = _redoStack.removeLast();
    _undoStack.add(action);
    await _replayRecordClosure(action.forward);
  }

  /// Runs one record closure and notifies listeners: synchronously for a
  /// synchronous closure, holding the [_isReplaying] guard across an await for
  /// an asynchronous one.
  Future<void> _replayRecordClosure(FutureOr<void> Function() closure) async {
    final FutureOr<void> result = closure();
    if (result is Future<void>) {
      _isReplaying = true;
      try {
        await result;
      } finally {
        _isReplaying = false;
      }
    }
    notifyListeners();
  }

  /// Clears the undo and redo stacks.
  void clear() {
    final List<RecordAction> dropped = <RecordAction>[..._undoStack, ..._redoStack];
    _undoStack.clear();
    _redoStack.clear();
    _dropRecords(dropped);
    notifyListeners();
  }

  /// Reports already-detached [records] as permanently dropped so their retained
  /// textures can be freed. Call this only *after* the records have been removed
  /// from the live stacks, so the owner's reachability check excludes them.
  void _dropRecords(List<RecordAction> records) {
    if (onRecordsDropped == null || records.isEmpty) {
      return;
    }
    final List<RecordAction> withImages = records
        .where((RecordAction r) => r.retainedImages.isNotEmpty)
        .toList(growable: false);
    if (withImages.isNotEmpty) {
      onRecordsDropped!(withImages);
    }
  }

  /// Trims undo history for actions that match [predicate], keeping only
  /// the latest [maxKeep] matches.
  ///
  /// Useful for tools with expensive replay cost (for example pixel-brush
  /// smudge/blur) where long histories can degrade runtime performance.
  void trimUndoHistoryWhere({
    required bool Function(RecordAction) predicate,
    required int maxKeep,
  }) {
    if (maxKeep < AppMath.zero) {
      return;
    }

    int kept = AppMath.zero;
    final List<RecordAction> dropped = <RecordAction>[];
    for (int index = _undoStack.length - AppMath.one; index >= AppMath.zero; index--) {
      final RecordAction action = _undoStack[index];
      if (!predicate(action)) {
        continue;
      }
      if (kept < maxKeep) {
        kept++;
        continue;
      }
      _undoStack.removeAt(index);
      dropped.add(action);
    }

    if (dropped.isNotEmpty) {
      // A trim also invalidates the redo stack; those records are dropped too.
      dropped.addAll(_redoStack);
      _redoStack.clear();
      _dropRecords(dropped);
      notifyListeners();
    }
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
  String getHistoryString(List<RecordAction> list) {
    try {
      return this.getActionsAsStrings(list, AppLimits.topColorCount).join('\n');
    } catch (error) {
      _log.severe('Failed to get history', error);
      return _errorFallback;
    }
  }

  /// Gets the actions as a list of strings.
  List<String> getActionsAsStrings(
    List<RecordAction> list, [
    int? numberOfHistoryAction,
  ]) {
    return list
        .take(numberOfHistoryAction ?? list.length)
        .map((RecordAction action) => action.toString())
        .toList()
        .reversed
        .toList();
  }
}

/// Represents an action that can be undone and redone.
class RecordAction {
  RecordAction({
    required this.name,
    required this.backward,
    required this.forward,
    this.retainedImages = const <ui.Image>[],
  });

  /// The name of the action.
  String name;

  /// The function to call to execute the action.
  ///
  /// May be asynchronous (registered through
  /// [UndoProvider.executeActionAsync]); replay awaits it so state mutations
  /// never interleave with a follow-up action.
  FutureOr<void> Function() forward;

  /// The function to call to undo the action; same contract as [forward].
  FutureOr<void> Function() backward;

  /// GPU textures this record's [forward]/[backward] closures can resurrect.
  ///
  /// Owners list every committed [ui.Image] an undo/redo of this action could
  /// reintroduce, so a coordinator can keep them alive while the record lives
  /// and dispose them once it is dropped and nothing else references them.
  final List<ui.Image> retainedImages;

  @override
  String toString() {
    return name;
  }
}
