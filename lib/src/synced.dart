import 'dart:async';
import 'dart:developer';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';

import 'sync_manager.dart';

typedef Dataset<T> = IMap<String, T>;

class SyncConfig<T> {
  final Dataset<T>? initialState;
  final SyncManager<T> manager;
  final SortConfig<T> sortConfig;
  Future Function(Dataset<T> state, SyncedState<T> obj)? initializeCallback;
  final Completer<void> completer;

  SyncConfig({
    this.initialState,
    required this.manager,
    this.sortConfig = const SortConfig(),
    this.initializeCallback,
  }) : completer = Completer<void>();

  @override
  bool operator ==(Object other) {
    return other is SyncConfig &&
        other.initialState == initialState &&
        other.sortConfig == sortConfig &&
        other.manager == manager;
  }

  @override
  int get hashCode => Object.hash(initialState, sortConfig, manager);
}

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

/* Here we are manually sorting the map each time, ideally, we should have a
separate object, which stores data in sorted manner, with log n complexities */

/// Use it in the following way:-
/// ```dart
/// @riverpod
/// class Temp extends _$Temp with SyncObj<int> {
///   @override
///   int build() {
///     // create `params` as the `SyncObjParams<int>` object.
///     return initialize(params);
///   }
/// }
/// ```
mixin SyncedState<T> {
  late SyncConfig<T> _params;

  Dataset<T> get state;

  set state(Dataset<T> value);

  Dataset<T> initialize(SyncConfig<T> params) {
    _params = params;
    _initialize();
    return _sort(
      _params.initialState ?? <String, T>{}.lock,
      _params.sortConfig,
    );
  }

  void _initialize() async {
    await refresh();
    await _params.initializeCallback?.call(state, this);
    _params.completer.complete();
  }

  Future<void> refresh() async {
    await _params.manager.initialize();
    _setState(_params.manager.allFromStorage);

    try {
      final data = await _params.manager.fetchAndSyncFromNetwork;
      _setState(data);
    } catch (err) {
      log('err: $err', name: 'SyncObjNotifier');
    }
  }

  Future<void> get waitForInitialization => _params.completer.future;

  void _setState(Dataset<T> state) {
    this.state = _sort(state, _params.sortConfig);
  }

  static IMap<String, T> _sort<T>(
    IMap<String, T> state,
    SortConfig<T> params,
  ) {
    if (!params.isSorted) return state;

    return Map.fromEntries(
      state.entries.toList()..sort((a, b) => params.compare(a.value, b.value)),
    ).lock;
  }

  Future<void> remove(String id) async => removeAll([id]);

  Future<void> removeAll(Iterable<String> ids) async {
    for (final id in ids) {
      if (!state.containsKey(id)) {
        throw PlatformException(
          code: 'ID_DOES_NOT_EXIST',
          message: 'Object removal does not exist.',
        );
      }
    }

    await _params.manager.remove(
      IMap.fromEntries(ids.map((id) => MapEntry(id, state[id] as T))),
    );

    final updatedState = state.unlock;
    for (final id in ids) {
      updatedState.remove(id);
    }
    state = updatedState.lock;
  }

  Future<void> update(T value) async {
    final id = _params.manager.stdObjParams.getId(value);
    await _params.manager.update({id: value}.lock);
    if (!_params.sortConfig.isSorted || state.isEmpty) {
      state = state.add(id, value);
      return;
    }

    bool added = false;
    List<MapEntry<String, T>> updatedStateEntries = [];
    for (final entry in state.entries) {
      if (!added && _params.sortConfig.compare(value, entry.value) <= 0) {
        added = true;
        updatedStateEntries.add(MapEntry(id, value));
      }
      if (entry.key != id) updatedStateEntries.add(entry);
    }
    if (!added) updatedStateEntries.add(MapEntry(id, value));
    state = IMap.fromEntries(updatedStateEntries);
  }

  Future<void> clear() async {
    await _params.manager.clear();
    state = Dataset<T>();
  }
}
