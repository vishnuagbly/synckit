import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'local_storage.dart';
import 'network_storage.dart';
import 'std_obj.dart';
import 'synced.dart';

class SyncManager<T> {
  final StdObjParams<T> stdObjParams;
  final LocalStorage<T> storage;
  final NetworkStorage<T> network;

  factory SyncManager.fromStdObj({
    required FromJson<T> fromJson,
    required LocalStorage<T> storage,
    required NetworkStorage<T> network,
  }) =>
      SyncManager(
        stdObjParams: StdObjParams(fromJson: fromJson),
        storage: storage,
        network: network,
      );

  const SyncManager({
    required this.stdObjParams,
    required this.storage,
    required this.network,
  });

  Dataset<T> get allFromStorage => storage.getAll(stdObjParams);

  Future<Dataset<T>> get allFromNetwork => network.getAll(stdObjParams);

  Future<void> update(IMap<String, T> data) async {
    /* It is important for "Network" call to be first, since if it fails there
    * is no point in adding it to storage, which will probably not fail, and
    * also we are using "Network" as the source of truth. */
    await network.update(data, stdObjParams);
    await storage.update(data, stdObjParams);
  }

  Future<void> remove(IMap<String, T> data) async {
    /* It is important for "Network" call to be first, since if it fails there
    * is no point in adding it to storage, which will probably not fail, and
    * also we are using "Network" as the source of truth. */
    await network.delete(data, stdObjParams);
    await storage.delete(data, stdObjParams);
  }

  Future<void> clear() async {
    await network.clear();
    await storage.clear();
  }

  Future<void> initialize() => storage.initialize();
}
