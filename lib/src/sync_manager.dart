import 'package:synckit/src/objects/batch.dart';

import 'local_storage.dart';
import 'network_storage.dart';
import 'objects/std_obj.dart';
import 'utils.dart';

class SyncManager<T> {
  final StdObjParams<T> stdObjParams;
  final LocalStorage<T> storage;
  final NetworkStorage<T> network;

  /// If true, whenever data is fetched from the network (`get all`), local storage
  /// will be replaced with this data.
  final bool syncLocalWithNetworkOnFetch;

  factory SyncManager.fromStdObj({
    required FromJson<T> fromJson,
    required LocalStorage<T> storage,
    required NetworkStorage<T> network,
    bool syncLocalWithNetworkOnFetch = true,
  }) =>
      SyncManager(
        stdObjParams: StdObjParams(fromJson: fromJson),
        storage: storage,
        network: network,
        syncLocalWithNetworkOnFetch: syncLocalWithNetworkOnFetch,
      );

  const SyncManager({
    required this.stdObjParams,
    required this.storage,
    required this.network,
    this.syncLocalWithNetworkOnFetch = true,
  });

  Dataset<T> get allFromStorage => storage.getAll(stdObjParams);

  Future<Dataset<T>> get allFromNetwork => network.getAll(stdObjParams);

  Future<Dataset<T>> get fetchAndSyncFromNetwork async {
    final res = await allFromNetwork;

    if (syncLocalWithNetworkOnFetch) {
      await storage.clear();
      await storage.update(res, stdObjParams);
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
    await syncBatch.completer.future;
    await storage.update(data, stdObjParams);
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
    await syncBatch.completer.future;
    await storage.delete(data, stdObjParams);
  }

  Future<void> batchClear(SyncBatch syncBatch) async {
    /* It is important for "Network" call to be first, since if it fails there
    * is no point in adding it to storage, which will probably not fail, and
    * also we are using "Network" as the source of truth. */

    await network.writeBatchClear(syncBatch.batch);
    await syncBatch.completer.future;
    await storage.clear();
  }

  Future<void> clear() async {
    await network.clear();
    await storage.clear();
  }

  Future<void> initialize() => storage.initialize();
}
