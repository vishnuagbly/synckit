import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';

class SortConfig<T> {
  final bool isSorted;

  /// - -ve:  if first < second
  /// - 0:    if first == second
  /// - +ve:  if first > second
  final int Function(T, T)? comparator;

  /// As Default, it is `false`, i.e in Descending order.
  final bool ascending;

  const SortConfig({
    this.isSorted = false,
    this.comparator,
    this.ascending = false,
  });

  int compare(T a, T b) {
    final entries = (ascending ? (a, b) : (b, a));
    var comparator = this.comparator;
    if (a is Comparable && b is Comparable && comparator == null) {
      comparator ??= (first, second) => first.compareObjectTo(second);
    }

    if (comparator == null) {
      throw PlatformException(
        code: 'COMPARATOR REQUIRED',
        message: 'Comparator is required for `$T` type',
      );
    }

    return comparator.call(entries.$1, entries.$2);
  }
}
