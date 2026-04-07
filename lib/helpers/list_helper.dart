// ignore: fcheck_one_class_per_file

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

/// Checks if an index is within the bounds of a list.
///
/// Returns true if the index is greater than or equal to 0 and less than the length of the list, otherwise returns false.
bool isIndexInRange(final List<dynamic> array, final int index) {
  return index >= 0 && index < array.length;
}

/// A class that represents a key-value pair.
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

/// A class that represents a pair of values.
class Pair<F, S> {
  Pair(this.first, this.second);

  F first;
  S second;

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Pair<F, S> && other.first == first && other.second == second;
  }

  @override
  int get hashCode => first.hashCode ^ second.hashCode;

  @override
  String toString() => '($first, $second)';
}

/// A class that represents a triple of values.
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
    return other is Triple<F, S, T> && other.first == first && other.second == second && other.third == third;
  }

  @override
  int get hashCode => first.hashCode ^ second.hashCode ^ third.hashCode;

  @override
  String toString() => '($first, $second, $third)';
}

/// Extension on Iterable to find the first match.
extension FindFirstMatchExtension<T> on Iterable<T> {
  /// Returns the first element that satisfies the given test, or null if no such element is found.
  T? findFirstMatch(final bool Function(T) test) {
    for (final T item in this) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}
