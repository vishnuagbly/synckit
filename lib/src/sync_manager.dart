import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:synckit/src/objects/batch.dart';

import 'local_storage.dart';
import 'network_storage.dart';
import 'objects/history.dart';
import 'objects/std_obj.dart';
import 'utils.dart';

class SyncManager<T> {
  History _history = const History();
  final StdObjParams<T> stdObjParams;
  final LocalStorage<T> storage;
  final NetworkStorage<T> network;

  /// If true, whenever data is fetched from the network (`get all`), local storage
  /// will be replaced with this data.
  final bool syncLocalWithNetworkOnFetch;

  final void Function(History history)? onHistoryUpdate;

  factory SyncManager.fromStdObj({
    required FromJson<T> fromJson,
    required LocalStorage<T> storage,
    required NetworkStorage<T> network,
    bool syncLocalWithNetworkOnFetch = true,
    void Function(History history)? onHistoryUpdate,
  }) =>
      SyncManager(
        stdObjParams: StdObjParams(fromJson: fromJson),
        storage: storage,
        network: network,
        syncLocalWithNetworkOnFetch: syncLocalWithNetworkOnFetch,
        onHistoryUpdate: onHistoryUpdate,
      );

  SyncManager({
    required this.stdObjParams,
    required this.storage,
    required this.network,
    this.syncLocalWithNetworkOnFetch = true,
    this.onHistoryUpdate,
  });

  History get history => _history;

  void _updateHistory(History history) {
    _history = history;
    onHistoryUpdate?.call(_history);
  }

  Dataset<T> get allFromStorage => storage.getAll(stdObjParams);

  Future<Dataset<T>> get allFromNetwork => network.getAll(stdObjParams);

  Future<Dataset<T>> get fetchAndSyncFromNetwork async {
    final res = await allFromNetwork;

    if (syncLocalWithNetworkOnFetch) {
      if (!network.collectionBased) {
        await storage.clear();
      }
      await storage.update(res, stdObjParams);
      _updateHistory(_history.updateLastSyncWithNetworkFetchTime());
    }

    return res;
  }

  /// This will keep local storage in sync with the network whenever there is a
  /// change in the network data. If `syncLocalWithNetworkOnFetch` is true,
  /// local storage will be updated with the new data whenever there is a change
  /// in the network data. Otherwise, local storage will not be updated, but the
  /// [onData] will still be called whenever there is a change in the network data.
  ///
  /// Note:- Local Storage data will be cleared then updated with the new data
  /// whenever there is a change in the network data, so if you don't want that,
  /// in that case, you can set `syncLocalWithNetworkOnFetch` to false and
  /// handle the local storage update in the listener.
  StreamSubscription<Dataset<T>> listenAllFromNetwork(
      [Function(Dataset<T>)? onData]) {
    final stream = network.streamAll(stdObjParams);
    return stream.listen((res) async {
      if (syncLocalWithNetworkOnFetch) {
        await storage.clear();
        await storage.update(res, stdObjParams);
        _updateHistory(_history.updateLastSyncWithNetworkFetchTime());
      }
      onData?.call(res);
    });
  }

  /// This will keep local storage in sync with the network whenever there is a
  /// change in the network data that matches the query. If
  /// `syncLocalWithNetworkOnFetch` is true, local storage will be updated as
  /// well.
  /// [onData] will be called always.
  StreamSubscription<Dataset<T>> listenQueryFromNetwork(QueryFn<T> queryFn,
      {int? maxGetAllDocs, Function(Dataset<T>)? onData}) {
    final stream = network.streamQuery(stdObjParams, queryFn, maxGetAllDocs);
    return stream.listen((res) async {
      if (syncLocalWithNetworkOnFetch) {
        await storage.update(res, stdObjParams);
        _updateHistory(_history.updateLastSyncWithNetworkFetchTime());
      }
      onData?.call(res);
    });
  }

  Future<Dataset<T>> getQueryFromNetwork(QueryFn<T> queryFn,
      [int? maxGetAllDocs, GetOptions? getOptions]) async {
    final res = await network.getQuery(
        stdObjParams, queryFn, maxGetAllDocs, getOptions);

    if (syncLocalWithNetworkOnFetch) {
      await storage.update(res, stdObjParams);
      _updateHistory(_history.updateLastSyncWithNetworkFetchTime());
    }
    return res;
  }

  Future<void> update(Dataset<T> data) async {
    /* It is important for "Network" call to be first, since if it fails there
    * is no point in adding it to storage, which will probably not fail, and
    * also we are using "Network" as the source of truth. */
    await network.update(data, stdObjParams);
    await storage.update(data, stdObjParams);
  }

  Future<void> batchUpdate(Dataset<T> data, SyncBatch syncBatch) async {
    /* It is important for "Network" call to be first, since if it fails there
    * is no point in adding it to storage, which will probably not fail, and
    * also we are using "Network" as the source of truth. */

    network.writeBatchUpdate(syncBatch.batch, data, stdObjParams);
    syncBatch.addAsyncCallback(() => storage.update(data, stdObjParams));
  }

  Future<void> remove(Dataset<T> data) async {
    /* It is important for "Network" call to be first, since if it fails there
    * is no point in adding it to storage, which will probably not fail, and
    * also we are using "Network" as the source of truth. */
    await network.delete(data, stdObjParams);
    await storage.delete(data, stdObjParams);
  }

  Future<void> batchRemove(Dataset<T> data, SyncBatch syncBatch) async {
    /* It is important for "Network" call to be first, since if it fails there
    * is no point in adding it to storage, which will probably not fail, and
    * also we are using "Network" as the source of truth. */

    network.writeBatchDelete(syncBatch.batch, data, stdObjParams);
    syncBatch.addAsyncCallback(() => storage.delete(data, stdObjParams));
  }

  Future<void> batchClear(SyncBatch syncBatch) async {
    /* It is important for "Network" call to be first, since if it fails there
    * is no point in adding it to storage, which will probably not fail, and
    * also we are using "Network" as the source of truth. */

    await network.writeBatchClear(syncBatch.batch);
    syncBatch.addAsyncCallback(() => storage.clear());
  }

  Future<void> clear() async {
    await network.clear();
    await storage.clear();
  }

  Future<void> initialize() => storage.initialize();

  bool isInitialized() => storage.isInitialized;
}
