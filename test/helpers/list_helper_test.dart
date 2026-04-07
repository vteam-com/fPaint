import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/list_helper.dart';

void main() {
  group('ListHelper Tests', () {
    group('calculateSpread', () {
      test('should return empty list for numEntries <= 1', () {
        expect(calculateSpread(0, 10, 1), isEmpty);
        expect(calculateSpread(0, 10, 0), isEmpty);
        expect(calculateSpread(0, 10, -1), isEmpty);
      });

      test('should return evenly spaced values', () {
        expect(calculateSpread(0, 10, 5), orderedEquals(<double>[0, 2.5, 5, 7.5, 10]));
        expect(calculateSpread(1, 5, 3), orderedEquals(<double>[1, 3, 5]));
        expect(calculateSpread(0, 0, 2), orderedEquals(<double>[0, 0]));
      });
    });

    group('isIndexInRange', () {
      final List<int> list = <int>[1, 2, 3];
      test('should return true for valid index', () {
        expect(isIndexInRange(list, 0), isTrue);
        expect(isIndexInRange(list, 1), isTrue);
        expect(isIndexInRange(list, 2), isTrue);
      });

      test('should return false for invalid index', () {
        expect(isIndexInRange(list, -1), isFalse);
        expect(isIndexInRange(list, 3), isFalse);
        expect(isIndexInRange(<dynamic>[], 0), isFalse);
      });
    });

    group('KeyValue Class', () {
      test('constructor and properties', () {
        final KeyValue kv = KeyValue(key: 'id', value: 123);
        expect(kv.key, 'id');
        expect(kv.value, 123);
      });

      test('equality', () {
        final KeyValue kv1 = KeyValue(key: 'a', value: 1);
        final KeyValue kv2 = KeyValue(key: 'a', value: 1);
        final KeyValue kv3 = KeyValue(key: 'b', value: 1);
        final KeyValue kv4 = KeyValue(key: 'a', value: 2);

        expect(kv1 == kv2, isTrue);
        expect(kv1.hashCode == kv2.hashCode, isTrue);
        expect(kv1 == kv3, isFalse);
        expect(kv1 == kv4, isFalse);
      });

      test('toString', () {
        final KeyValue kv = KeyValue(key: 'name', value: 'Test');
        expect(kv.toString(), 'name:Test');
      });
    });

    group('Pair Class', () {
      test('constructor and properties', () {
        final Pair<String, int> pair = Pair<String, int>('age', 30);
        expect(pair.first, 'age');
        expect(pair.second, 30);
      });

      test('equality', () {
        final Pair<String, int> p1 = Pair<String, int>('a', 1);
        final Pair<String, int> p2 = Pair<String, int>('a', 1);
        final Pair<String, int> p3 = Pair<String, int>('b', 1);
        final Pair<String, int> p4 = Pair<String, int>('a', 2);

        expect(p1 == p2, isTrue);
        expect(p1.hashCode == p2.hashCode, isTrue);
        expect(p1 == p3, isFalse);
        expect(p1 == p4, isFalse);
      });
      test('toString', () {
        final Pair<String, int> pair = Pair<String, int>('key', 100);
        expect(pair.toString(), '(key, 100)');
      });
    });

    group('Triple Class', () {
      test('constructor and properties', () {
        final Triple<String, int, bool> triple = Triple<String, int, bool>('data', 10, true);
        expect(triple.first, 'data');
        expect(triple.second, 10);
        expect(triple.third, isTrue);
      });

      test('equality', () {
        final Triple<String, int, bool> t1 = Triple<String, int, bool>('a', 1, true);
        final Triple<String, int, bool> t2 = Triple<String, int, bool>('a', 1, true);
        final Triple<String, int, bool> t3 = Triple<String, int, bool>('b', 1, true);
        final Triple<String, int, bool> t4 = Triple<String, int, bool>('a', 2, true);
        final Triple<String, int, bool> t5 = Triple<String, int, bool>('a', 1, false);

        expect(t1 == t2, isTrue);
        expect(t1.hashCode == t2.hashCode, isTrue);
        expect(t1 == t3, isFalse);
        expect(t1 == t4, isFalse);
        expect(t1 == t5, isFalse);
      });
      test('toString', () {
        final Triple<String, int, bool> triple = Triple<String, int, bool>('info', 1, false);
        expect(triple.toString(), '(info, 1, false)');
      });
    });

    group('Extensions', () {
      test('findFirstMatch from Iterable', () {
        final List<int> list = <int>[1, 2, 3, 4, 5];
        expect(list.findFirstMatch((final int x) => x > 3), 4);
        expect(list.findFirstMatch((final int x) => x == 3), 3);
        expect(list.findFirstMatch((final int x) => x > 10), isNull);
      });
    });
  });
}
