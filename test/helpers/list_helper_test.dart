import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'dart:math'; // For Random in getRandomItem test

enum TestEnum { valueA, valueB, valueC }

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

    group('getMinMaxValues', () {
      test('should return [0,0] for empty list', () {
        expect(getMinMaxValues([]), orderedEquals(<num>[0, 0]));
      });

      test('should return [value, value] for single element list', () {
        expect(getMinMaxValues([5.0]), orderedEquals(<num>[5.0, 5.0]));
      });

      test('should return correct min and max values', () {
        expect(getMinMaxValues([1.0, 5.0, 2.0, 8.0, 3.0]), orderedEquals(<num>[1.0, 8.0]));
        expect(getMinMaxValues([-1.0, -5.0, -2.0]), orderedEquals(<num>[-5.0, -1.0]));
        expect(getMinMaxValues([5.0, 1.0]), orderedEquals(<num>[1.0, 5.0])); // Test initial comparison
      });
    });

    group('isIndexInRange', () {
      final list = [1, 2, 3];
      test('should return true for valid index', () {
        expect(isIndexInRange(list, 0), isTrue);
        expect(isIndexInRange(list, 1), isTrue);
        expect(isIndexInRange(list, 2), isTrue);
      });

      test('should return false for invalid index', () {
        expect(isIndexInRange(list, -1), isFalse);
        expect(isIndexInRange(list, 3), isFalse);
        expect(isIndexInRange([], 0), isFalse);
      });
    });

    group('padList', () {
      test('should not pad if list is already long enough', () {
        expect(padList(['a', 'b', 'c'], 2, 'x'), orderedEquals(['a', 'b', 'c']));
        expect(padList(['a', 'b'], 2, 'x'), orderedEquals(['a', 'b']));
      });

      test('should pad list to specified length', () {
        expect(padList(['a'], 3, 'x'), orderedEquals(['a', 'x', 'x']));
        expect(padList([], 2, 'y'), orderedEquals(['y', 'y']));
      });
    });

    group('sortByDate', () {
      final date1 = DateTime(2023, 1, 1);
      final date2 = DateTime(2023, 1, 15);
      final date3 = DateTime(2024, 1, 1);

      test('should sort dates ascending by default', () {
        expect(sortByDate(date1, date2), -1); // date1 < date2
        expect(sortByDate(date2, date1), 1);  // date2 > date1
        expect(sortByDate(date1, date1), 0);  // date1 == date1
      });

      test('should sort dates descending', () {
        expect(sortByDate(date1, date2, false), 1);  // date1 < date2 (desc: date2 then date1)
        expect(sortByDate(date2, date1, false), -1); // date2 > date1 (desc: date1 then date2)
      });

      test('should handle null dates', () {
        expect(sortByDate(null, date1), -1); // nulls first ascending
        expect(sortByDate(date1, null), 1);
        expect(sortByDate(null, null), 0);

        expect(sortByDate(null, date1, false), 1); // nulls last descending
        expect(sortByDate(date1, null, false), -1);
      });
    });

    group('sortByValue', () {
      test('should sort numbers ascending', () {
        expect(sortByValue(1, 5, true), -1);
        expect(sortByValue(5, 1, true), 1);
        expect(sortByValue(1, 1, true), 0);
      });

      test('should sort numbers descending', () {
        expect(sortByValue(1, 5, false), 1);
        expect(sortByValue(5, 1, false), -1);
      });
    });

    group('KeyValue Class', () {
      test('constructor and properties', () {
        final kv = KeyValue(key: 'id', value: 123);
        expect(kv.key, 'id');
        expect(kv.value, 123);
      });

      test('equality', () {
        final kv1 = KeyValue(key: 'a', value: 1);
        final kv2 = KeyValue(key: 'a', value: 1);
        final kv3 = KeyValue(key: 'b', value: 1);
        final kv4 = KeyValue(key: 'a', value: 2);

        expect(kv1 == kv2, isTrue);
        expect(kv1.hashCode == kv2.hashCode, isTrue);
        expect(kv1 == kv3, isFalse);
        expect(kv1 == kv4, isFalse);
      });

      test('toString', () {
        final kv = KeyValue(key: 'name', value: 'Test');
        expect(kv.toString(), 'name:Test');
      });
    });

    group('Pair Class', () {
      test('constructor and properties', () {
        final pair = Pair<String, int>('age', 30);
        expect(pair.first, 'age');
        expect(pair.second, 30);
      });

      test('equality', () {
        final p1 = Pair<String, int>('a', 1);
        final p2 = Pair<String, int>('a', 1);
        final p3 = Pair<String, int>('b', 1);
        final p4 = Pair<String, int>('a', 2);

        expect(p1 == p2, isTrue);
        expect(p1.hashCode == p2.hashCode, isTrue);
        expect(p1 == p3, isFalse);
        expect(p1 == p4, isFalse);
      });
       test('toString', () {
        final pair = Pair<String, int>('key', 100);
        expect(pair.toString(), '(key, 100)');
      });
    });

    group('Triple Class', () {
      test('constructor and properties', () {
        final triple = Triple<String, int, bool>('data', 10, true);
        expect(triple.first, 'data');
        expect(triple.second, 10);
        expect(triple.third, isTrue);
      });

      test('equality', () {
        final t1 = Triple<String, int, bool>('a', 1, true);
        final t2 = Triple<String, int, bool>('a', 1, true);
        final t3 = Triple<String, int, bool>('b', 1, true);
        final t4 = Triple<String, int, bool>('a', 2, true);
        final t5 = Triple<String, int, bool>('a', 1, false);

        expect(t1 == t2, isTrue);
        expect(t1.hashCode == t2.hashCode, isTrue);
        expect(t1 == t3, isFalse);
        expect(t1 == t4, isFalse);
        expect(t1 == t5, isFalse);
      });
      test('toString', () {
        final triple = Triple<String, int, bool>('info', 1, false);
        expect(triple.toString(), '(info, 1, false)');
      });
    });

    group('enumToStringList', () {
      test('should convert enum list to string list', () {
        final enumList = [TestEnum.valueA, TestEnum.valueB, TestEnum.valueC];
        expect(enumToStringList(enumList), orderedEquals(['valueA', 'valueB', 'valueC']));
      });
       test('should return empty list for empty enum list', () {
        expect(enumToStringList(<TestEnum>[]), isEmpty);
      });
    });

    group('Extensions', () {
      test('getRandomItem from List', () {
        final list = [1, 2, 3, 4, 5];
        final randomItem = list.getRandomItem();
        expect(list.contains(randomItem), isTrue);

        final singleItemList = [10];
        expect(singleItemList.getRandomItem(), 10);

        expect(() => <int>[].getRandomItem(), throwsException);
      });

      test('findFirstMatch from Iterable', () {
        final list = [1, 2, 3, 4, 5];
        expect(list.findFirstMatch((x) => x > 3), 4);
        expect(list.findFirstMatch((x) => x == 3), 3);
        expect(list.findFirstMatch((x) => x > 10), isNull);
        expect([].findFirstMatch((x) => true), isNull);
      });

      test('firstWhereOrNull from List (FirWheresOrNull extension)', () {
        final list = [10, 20, 30, 40, 50];
        expect(list.firstWhereOrNull((x) => x > 25), 30);
        expect(list.firstWhereOrNull((x) => x == 20), 20);
        expect(list.firstWhereOrNull((x) => x > 100), isNull);
        expect(<int>[].firstWhereOrNull((x) => true), isNull);
      });
    });

    group('uint8ListToHex', () {
      test('should convert Uint8List to hex string', () {
        expect(uint8ListToHex(Uint8List.fromList([])), '');
        expect(uint8ListToHex(Uint8List.fromList([0, 1, 2])), '000102');
        expect(uint8ListToHex(Uint8List.fromList([10, 17, 255])), '0a11ff'); // a, 11, ff
        expect(uint8ListToHex(Uint8List.fromList([255, 255, 255])), 'ffffff');
      });
    });
  });
}
