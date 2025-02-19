import 'dart:math';
import 'dart:typed_data';

/// Calculates a list of evenly spaced values between a start and end value.
///
/// This function takes a start value, an end value, and the desired number of
/// entries in the resulting list. It calculates the step size between each
/// value and generates a list of evenly spaced values between the start and
/// end values.
///
/// If the number of entries is less than or equal to 1, an empty list is
/// returned.
///
/// Example usage:
///
/// ```dart
/// List<double> spread = calculateSpread(1.0, 5.0, 5);
/// print(spread); // Output: [1.0, 2.0, 3.0, 4.0, 5.0]
/// ```
///
/// Parameters:
///   start (double): The starting value of the spread.
///   end (double): The ending value of the spread.
///   numEntries (int): The desired number of entries in the resulting list.
///
/// Returns:
///   A list of evenly spaced values between the start and end values.
///   If numEntries is less than or equal to 1, an empty list is returned.
List<double> calculateSpread(
  final double start,
  final double end,
  final int numEntries,
) {
  // Check if numEntries is valid
  if (numEntries <= 1) {
    return <double>[];
  }

  // Calculate the step size between each value
  final double step = (end - start) / (numEntries - 1);

  // Initialize an empty list to store the spread values
  final List<double> spread = <double>[];

  // Generate the spread values and add them to the list
  for (int i = 0; i < numEntries; i++) {
    spread.add(start + i * step);
  }

  return spread;
}

List<num> getMinMaxValues(final List<double> list) {
  if (list.isEmpty) {
    return <num>[0, 0];
  }
  if (list.length == 1) {
    return <num>[list[0], list[0]];
  }

  double valueMin = 0.0;
  double valueMax = 0.0;
  if (list[0] < list[1]) {
    valueMin = list[0];
    valueMax = list[1];
  } else {
    valueMin = list[1];
    valueMax = list[0];

    for (final double value in list) {
      valueMin = min(valueMin, value);
      valueMax = max(valueMax, value);
    }
  }
  return <num>[valueMin, valueMax];
}

bool isIndexInRange(final List<dynamic> array, final int index) {
  return index >= 0 && index < array.length;
}

List<String> padList(
  final List<String> list,
  final int length,
  final String padding,
) {
  if (list.length >= length) {
    return list;
  }
  final List<String> paddedList = List<String>.from(list);
  for (int i = list.length; i < length; i++) {
    paddedList.add(padding);
  }
  return paddedList;
}

int sortByDate(
  final DateTime? a,
  final DateTime? b, [
  final bool ascending = true,
]) {
  if (a == null && b == null) {
    return 0;
  }

  if (ascending) {
    if (a == null) {
      return -1;
    }
    if (b == null) {
      return 1;
    }
    return a.compareTo(b);
  } else {
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return b.compareTo(a);
  }
}

int sortByValue(final num a, final num b, final bool ascending) {
  if (ascending) {
    return a.compareTo(b);
  } else {
    return b.compareTo(a);
  }
}

class KeyValue {
  KeyValue({required this.key, required this.value});

  dynamic key;
  dynamic value;

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! KeyValue) {
      return false;
    }

    final KeyValue otherKeyValue = other;
    return key == otherKeyValue.key && value == otherKeyValue.value;
  }

  @override
  int get hashCode => Object.hash(key, value);

  @override
  String toString() {
    return '$key:$value';
  }
}

class Pair<F, S> {
  Pair(this.first, this.second);

  F first;
  S second;

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Pair<F, S> &&
        other.first == first &&
        other.second == second;
  }

  @override
  int get hashCode => first.hashCode ^ second.hashCode;

  @override
  String toString() => '($first, $second)';
}

class Triple<F, S, T> {
  Triple(this.first, this.second, this.third);

  F first;
  S second;
  T third;

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Triple<F, S, T> &&
        other.first == first &&
        other.second == second &&
        other.third == third;
  }

  @override
  int get hashCode => first.hashCode ^ second.hashCode ^ third.hashCode;

  @override
  String toString() => '($first, $second, $third)';
}

List<String> enumToStringList<T>(final List<T> enumValues) {
  return enumValues.map((final T e) => e.toString().split('.').last).toList();
}

extension RandomItemExtension<T> on List<T> {
  T getRandomItem() {
    final Random random = Random();
    if (isEmpty) {
      throw Exception('Cannot get random item from an empty list');
    }
    return this[random.nextInt(length)];
  }
}

extension FindFirstMatchExtension<T> on Iterable<T> {
  T? findFirstMatch(final bool Function(T) test) {
    for (final T item in this) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}

extension FirWheresOrNull<T> on List<T> {
  T? firstWhereOrNull(final bool Function(T) test) {
    for (final T item in this) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}

String uint8ListToHex(final Uint8List list) {
  final StringBuffer hexString = StringBuffer();
  for (final int byte in list) {
    hexString.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return hexString.toString();
}
