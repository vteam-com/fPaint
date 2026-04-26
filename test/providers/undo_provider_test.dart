import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/undo_provider.dart';

void main() {
  late UndoProvider provider;

  setUp(() {
    provider = UndoProvider();
    provider.clear();
  });

  group('UndoProvider initial state', () {
    test('canUndo is false when empty', () {
      expect(provider.canUndo, isFalse);
    });

    test('canRedo is false when empty', () {
      expect(provider.canRedo, isFalse);
    });

    test('undo history is empty', () {
      expect(provider.getHistoryStringForUndo(), isEmpty);
    });

    test('redo history is empty', () {
      expect(provider.getHistoryStringForRedo(), isEmpty);
    });
  });

  group('recordAction', () {
    test('adds action to undo stack', () {
      provider.recordAction(
        RecordAction(
          name: 'draw',
          forward: () {},
          backward: () {},
        ),
      );
      expect(provider.canUndo, isTrue);
      expect(provider.canRedo, isFalse);
    });

    test('clears redo stack when new action is recorded', () {
      // Record, undo, then record again
      provider.executeAction(
        name: 'first',
        forward: () {},
        backward: () {},
      );
      provider.undo();
      expect(provider.canRedo, isTrue);

      provider.recordAction(
        RecordAction(
          name: 'second',
          forward: () {},
          backward: () {},
        ),
      );
      expect(provider.canRedo, isFalse);
    });
  });

  group('executeAction', () {
    test('executes the forward callback', () {
      int counter = 0;
      provider.executeAction(
        name: 'increment',
        forward: () => counter++,
        backward: () => counter--,
      );
      expect(counter, 1);
    });

    test('records action to undo stack', () {
      provider.executeAction(
        name: 'action',
        forward: () {},
        backward: () {},
      );
      expect(provider.canUndo, isTrue);
    });

    test('returns the created RecordAction', () {
      final RecordAction result = provider.executeAction(
        name: 'test',
        forward: () {},
        backward: () {},
      );
      expect(result.name, 'test');
    });

    test('notifies listeners', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.executeAction(
        name: 'action',
        forward: () {},
        backward: () {},
      );
      expect(notifyCount, 1);
    });
  });

  group('undo', () {
    test('calls backward on the last action', () {
      int counter = 0;
      provider.executeAction(
        name: 'increment',
        forward: () => counter++,
        backward: () => counter--,
      );
      expect(counter, 1);

      provider.undo();
      expect(counter, 0);
    });

    test('moves action to redo stack', () {
      provider.executeAction(
        name: 'action',
        forward: () {},
        backward: () {},
      );
      provider.undo();
      expect(provider.canUndo, isFalse);
      expect(provider.canRedo, isTrue);
    });

    test('does nothing when stack is empty', () {
      provider.undo(); // should not throw
      expect(provider.canUndo, isFalse);
    });

    test('undoes multiple actions in reverse order', () {
      final List<String> log = <String>[];
      provider.executeAction(
        name: 'A',
        forward: () => log.add('A'),
        backward: () => log.add('undo-A'),
      );
      provider.executeAction(
        name: 'B',
        forward: () => log.add('B'),
        backward: () => log.add('undo-B'),
      );
      provider.undo();
      provider.undo();
      expect(log, <String>['A', 'B', 'undo-B', 'undo-A']);
    });

    test('notifies listeners', () {
      provider.executeAction(
        name: 'action',
        forward: () {},
        backward: () {},
      );
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      provider.undo();
      expect(notifyCount, 1);
    });
  });

  group('redo', () {
    test('calls forward on the last undone action', () {
      int counter = 0;
      provider.executeAction(
        name: 'increment',
        forward: () => counter++,
        backward: () => counter--,
      );
      provider.undo();
      expect(counter, 0);

      provider.redo();
      expect(counter, 1);
    });

    test('moves action back to undo stack', () {
      provider.executeAction(
        name: 'action',
        forward: () {},
        backward: () {},
      );
      provider.undo();
      provider.redo();
      expect(provider.canUndo, isTrue);
      expect(provider.canRedo, isFalse);
    });

    test('does nothing when redo stack is empty', () {
      provider.redo(); // should not throw
      expect(provider.canRedo, isFalse);
    });

    test('notifies listeners', () {
      provider.executeAction(
        name: 'action',
        forward: () {},
        backward: () {},
      );
      provider.undo();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      provider.redo();
      expect(notifyCount, 1);
    });
  });

  group('undo/redo round-trip', () {
    test('full cycle preserves state', () {
      int value = 0;
      provider.executeAction(
        name: 'set-10',
        forward: () => value = 10,
        backward: () => value = 0,
      );
      expect(value, 10);

      provider.undo();
      expect(value, 0);

      provider.redo();
      expect(value, 10);
    });

    test('multiple undo then multiple redo', () {
      int value = 0;
      provider.executeAction(
        name: 'add-1',
        forward: () => value += 1,
        backward: () => value -= 1,
      );
      provider.executeAction(
        name: 'add-10',
        forward: () => value += 10,
        backward: () => value -= 10,
      );
      provider.executeAction(
        name: 'add-100',
        forward: () => value += 100,
        backward: () => value -= 100,
      );
      expect(value, 111);

      provider.undo();
      provider.undo();
      provider.undo();
      expect(value, 0);

      provider.redo();
      provider.redo();
      provider.redo();
      expect(value, 111);
    });
  });

  group('clear', () {
    test('empties both stacks', () {
      provider.executeAction(
        name: 'action',
        forward: () {},
        backward: () {},
      );
      provider.undo();
      expect(provider.canRedo, isTrue);

      provider.clear();
      expect(provider.canUndo, isFalse);
      expect(provider.canRedo, isFalse);
    });

    test('notifies listeners', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      provider.clear();
      expect(notifyCount, 1);
    });
  });

  group('getHistoryString', () {
    test('returns action names for undo stack', () {
      provider.executeAction(
        name: 'draw-line',
        forward: () {},
        backward: () {},
      );
      provider.executeAction(
        name: 'fill-color',
        forward: () {},
        backward: () {},
      );
      final String history = provider.getHistoryStringForUndo();
      expect(history, contains('draw-line'));
      expect(history, contains('fill-color'));
    });

    test('returns action names for redo stack', () {
      provider.executeAction(
        name: 'action-A',
        forward: () {},
        backward: () {},
      );
      provider.undo();
      final String history = provider.getHistoryStringForRedo();
      expect(history, contains('action-A'));
    });

    test('returns empty string when stack is empty', () {
      expect(provider.getHistoryStringForUndo(), isEmpty);
      expect(provider.getHistoryStringForRedo(), isEmpty);
    });
  });

  group('getActionsAsStrings', () {
    test('returns reversed list of action names', () {
      provider.executeAction(
        name: 'A',
        forward: () {},
        backward: () {},
      );
      provider.executeAction(
        name: 'B',
        forward: () {},
        backward: () {},
      );
      provider.executeAction(
        name: 'C',
        forward: () {},
        backward: () {},
      );

      final List<String> result = provider.getActionsAsStrings(
        <RecordAction>[
          RecordAction(name: 'A', forward: () {}, backward: () {}),
          RecordAction(name: 'B', forward: () {}, backward: () {}),
          RecordAction(name: 'C', forward: () {}, backward: () {}),
        ],
      );
      // Reversed order
      expect(result, <String>['C', 'B', 'A']);
    });

    test('respects numberOfHistoryAction limit', () {
      final List<String> result = provider.getActionsAsStrings(
        <RecordAction>[
          RecordAction(name: 'A', forward: () {}, backward: () {}),
          RecordAction(name: 'B', forward: () {}, backward: () {}),
          RecordAction(name: 'C', forward: () {}, backward: () {}),
        ],
        2,
      );
      // Takes first 2 (A, B), then reverses
      expect(result, <String>['B', 'A']);
    });
  });

  group('RecordAction', () {
    test('toString returns the name', () {
      final RecordAction action = RecordAction(
        name: 'my-action',
        forward: () {},
        backward: () {},
      );
      expect(action.toString(), 'my-action');
    });
  });

  group('singleton behavior', () {
    test('factory returns the same instance', () {
      final UndoProvider a = UndoProvider();
      final UndoProvider b = UndoProvider();
      expect(identical(a, b), isTrue);
    });
  });
}
