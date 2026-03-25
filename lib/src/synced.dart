import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:synckit/src/utils.dart';

import 'objects/batch.dart';
import 'objects/history.dart';
import 'objects/sort_config.dart';
import 'objects/sync_config.dart';

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
  final List<StreamSubscription<Dataset<T>>> _subscriptions = [];
  History _history = const History();

  Dataset<T> get state;

  History get history => _history;

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

    try {
      _setState(_params.manager.allFromStorage);
    } catch (err) {
      log('err: $err', name: 'SyncObjNotifier');
    }

    try {
      final data = await _params.manager.fetchAndSyncFromNetwork;
      _setState(data);
      _updateHistory(_history.updateLastSyncWithNetworkFetchTime());
    } catch (err) {
      log('err: $err', name: 'SyncObjNotifier');
    }
  }

  Future<void> get waitForInitialization => _params.completer.future;

  /// Make sure to cancel the returned subscription in `dispose` method to avoid
  /// memory leaks.
  /// Note:- You can also simply call [dispose] method to cancel all the active
  /// subscriptions at once.
  StreamSubscription<Dataset<T>> keepAllInSync() {
    return _addSubscription(_params.manager.listenAllFromNetwork((data) {
      _setState(data);
      _updateHistory(_history.updateLastSyncWithNetworkFetchTime());
    }));
  }

  /// Make sure to cancel the returned subscription in `dispose` method to avoid
  /// memory leaks.
  /// Note:- You can also simply call [dispose] method to cancel all the active
  /// subscriptions at once.
  StreamSubscription<Dataset<T>> keepQueryInSync(QueryFn<T> queryFn,
      {int? maxGetAllDocs}) {
    return _addSubscription(_params.manager.listenQueryFromNetwork(
      queryFn,
      maxGetAllDocs: maxGetAllDocs,
      onData: (data) {
        _updateStateWithDataset(data);
        _updateHistory(_history.updateLastSyncWithNetworkFetchTime());
      },
    ));
  }

  StreamSubscription<Dataset<T>> _addSubscription(
      StreamSubscription<Dataset<T>> subscription) {
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Call this method in the `dispose` method of the notifier to cancel all the
  /// active subscriptions at once and avoid memory leaks.
  Future<void> dispose() async {
    await Future.wait(_subscriptions.map((sub) => sub.cancel()));
    _subscriptions.clear();
  }

  Future<Dataset<T>> getQueryFromNetwork(
    QueryFn<T> queryFn, {
    int? maxGetAllDocs,
    GetOptions? getOptions,
  }) async {
    final data =
        await _params.manager.getQueryFromNetwork(queryFn, maxGetAllDocs, getOptions);
    _updateStateWithDataset(data);
    _updateHistory(_history.updateLastSyncWithNetworkFetchTime());
    return data;
  }

  void _updateHistory(History history) {
    _history = history;
    _params.onHistoryUpdate?.call(_history);
  }

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

  Future<void> remove(String id, {bool stateOnly = false}) async =>
      removeAll([id], stateOnly: stateOnly);

  Future<void> removeAll(Iterable<String> ids, {bool stateOnly = false}) async {
    _assertIdsExists(ids);
    if (!stateOnly) {
      await _params.manager.remove(_idsDatasetFromState(ids));
    }
    _removeStateIds(ids);
  }

  void batchRemoveAll(Iterable<String> ids, SyncBatch batch) {
    _assertIdsExists(ids);
    _params.manager.batchRemove(_idsDatasetFromState(ids), batch);
    _removeStateIds(ids);
  }

  void _assertIdsExists(Iterable<String> ids) {
    for (final id in ids) {
      if (!state.containsKey(id)) {
        throw PlatformException(
          code: 'ID_NOT_FOUND',
          message: 'ID $id not found in the current state.',
        );
      }
    }
  }

  Dataset<T> _idsDatasetFromState(Iterable<String> ids) {
    return IMap.fromEntries(ids.map((id) => MapEntry(id, state[id] as T)));
  }

  void _removeStateIds(Iterable<String> ids) {
    final updatedState = state.unlock;
    for (final id in ids) {
      updatedState.remove(id);
    }
    state = updatedState.lock;
  }

  /// If `stateOnly` is true, the update will not be applied to local and network storage.
  Future<void> update(T value, {bool stateOnly = false}) async {
    final data = _toDataset(value);
    if (!stateOnly) {
      await _params.manager.update(data);
    }
    _updateStateWithValue(value);
  }

  /// NOTE: Make sure to call `batch.commit()` after calling this method.
  void batchUpdate(T value, SyncBatch batch) async {
    final data = _toDataset(value);
    await _params.manager.batchUpdate(data, batch);
    _updateStateWithValue(value);
  }

  Dataset<T> _toDataset(T value) {
    final id = _params.manager.stdObjParams.getId(value);
    return {id: value}.lock;
  }

  void _updateStateWithDataset(Dataset<T> dataset) {
    for (final entry in dataset.entries) {
      _updateStateWithValue(entry.value);
    }
  }

  void _updateStateWithValue(T value) {
    final id = _params.manager.stdObjParams.getId(value);
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

  Future<void> clear({bool stateOnly = false}) async {
    if (!stateOnly) {
      await _params.manager.clear();
    }
    state = Dataset<T>();
  }

  /// NOTE: Make sure to call `batch.commit()` after calling this method.
  Future<void> batchClear(SyncBatch batch) async {
    await _params.manager.batchClear(batch);
    state = Dataset<T>();
  }
}
