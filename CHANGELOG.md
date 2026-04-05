## 0.4.1

### Bug Fixes
- **[NetworkStorage]**: Fixed `streamDeletedDocsData` and `getDeletedDocsData` to properly compute the deleted docs path using `getDeletedDocsPath()` for collection-based storage support.


## 0.4.0

### New Features

#### "Deleted Docs" Tracking & Sync
Added a system to track document deletions and synchronize them across network and local storage, ensuring that deletes on one client are propagated to others.

- **[Utils]**: Added `DeleteDocData` type alias (`Map<String, int>`) for representing deleted document metadata (ID → deletion timestamp).

- **[NetworkStorage]**: Added `getDeletedDocsPath(bool collectionBased, String path)` static method to compute the Firestore path for storing deleted docs metadata.
- **[NetworkStorage]**: Added `streamDeletedDocsData([String? docPath])` to stream deleted docs data in real-time.
- **[NetworkStorage]**: Added `getDeletedDocsData([String? docPath])` to fetch deleted docs data.
- **[NetworkStorage]**: Added `transactionDeleteDoc(Transaction, Dataset<T>, [String? docPath])` to write deleted doc metadata within a Firestore transaction.
- **[NetworkStorage]**: `delete`, `transactionDelete`, and `writeBatchDelete` now also record deletion metadata to a separate deleted-docs document, enabling cross-client deletion sync.

- **[LocalStorage]**: Added `deleteFromIds(Iterable<String> ids)` method to delete entries by IDs directly, without requiring a full `Dataset`.

- **[SyncManager]**: Added `syncDeletedDocs` parameter (default: `false`) to opt-in to fetching and syncing deleted docs data from the network.
- **[SyncManager]**: Added `dispose()` method to cancel all active stream subscriptions and prevent memory leaks. Subscription management has been moved here from `SyncedState`.
- **[SyncManager]**: `fetchAndSyncFromNetwork` now also fetches deleted docs data and removes those entries from local storage.
- **[SyncManager]**: `listenQueryFromNetwork` now accepts an `onDeletedData` callback; when `syncDeletedDocs` is enabled, it also listens to the deleted docs stream.
- **[SyncManager]**: `getQueryFromNetwork` now accepts an `onDeletedData` callback; when `syncDeletedDocs` is enabled, it also fetches deleted docs data.

- **[SyncedState]**: `keepQueryInSync` now handles deleted docs by removing their IDs from state.
- **[SyncedState]**: `getQueryFromNetwork` now handles deleted docs by removing their IDs from state.
- **[SyncedState]**: `dispose()` now delegates to `SyncManager.dispose()`, centralizing subscription management.

## 0.3.19
- **[SyncedState]**: Added a new optional parameter on `refresh`, i.e `throwError`, allowing users to catch errors, in-case any part of the refresh fails. 

## 0.3.18

### Improvements
- **[SyncBatch]**: Replaced `Completer<void>` with callback-based approach. Added `asyncCallbacks` and `syncCallbacks` lists with `addAsyncCallback()` and `addSyncCallback()` methods for more flexible post-commit operations.
- **[SyncManager]**: `batchUpdate`, `batchRemove`, and `batchClear` now execute local storage operations as async callbacks within the batch commit process. When you `await` the batch commit, it will only complete successfully after all local storage operations have finished; if any of these operations fail, the commit will fail as well.
- **[SyncedState]**: `batchRemoveAll`, `batchUpdate`, and `batchClear` now schedule state updates via sync callbacks, so that batch commit only returns after successful completion of state update operations as well.

## 0.3.17

- **[SyncedState]** Removed `_assertIdsExists` check on all types of `remove` methods. 

## 0.3.16

### Improvements
- **[SyncManager]**: Modified `fetchAndSyncFromNetwork` to skip `storage.clear()` when `collectionBased` is enabled. 

- **[SyncedState]**: Updated `refresh` and `keepAllInSync` to use a new `_setOrUpdateState` method. This ensures that for `collectionBased` storage, the state is updated incrementally instead of being completely overwritten.

## 0.3.15+1
Bug fix on the `FirebaseException` handling.

## 0.3.15
### Improvements
- **[NetworkStorage]**: Enhanced `getQuery` to catch `FirebaseException` with code `unavailable` and throw a `PlatformException` with code `CONN_FAILURE` for better connection failure handling.

## 0.3.14
### New Features
- **[NetworkStorage]**: Added `defaultGetOptions` to `NetworkStorage` to control the default Firestore `Source` (server/cache) for fetch operations. Defaults to `Source.server`.
- **[NetworkStorage]**: Updated `getAll` and `getQuery` to accept custom `GetOptions`.
- **[SyncManager]**: Updated `getQueryFromNetwork` to support passing custom `GetOptions`.
- **[SyncedState]**: Updated `getQueryFromNetwork` to support passing custom `GetOptions`.

## 0.3.13
### New Features
- **[History]**: Made `History` object immutable and added `updateLastSyncWithNetworkFetchTime()` method that returns a new `History` instance.
- **[SyncConfig]**: Added `onHistoryUpdate` callback that is triggered whenever the history is updated in `SyncedState`.
- **[SyncedState]**: Updated to use the immutable `History` pattern and invoke `onHistoryUpdate` callback.
- **[SyncManager]**: Updated to use the immutable `History` pattern and added `onHistoryUpdate` callback.

## 0.3.12
### New Features
- **[History]**: Added a new `History` object with `lastSyncWithNetworkFetchTime` and `updateLastSyncWithNetworkFetchTime()` to track the latest successful network fetch sync time.
- **[SyncManager]**: Added `history` to track `lastSyncWithNetworkFetchTime` whenever network fetch/listen/query operations sync data to local storage.
- **[SyncedState]**: Added `history` updates in `refresh`, `keepAllInSync`, `keepQueryInSync`, and `getQueryFromNetwork` after network data is applied to state.

## 0.3.11+1
- **[NetworkStorage]**: Fixed a bug in `writeRules` where on executing `writeRuels` it was throwing error, instead now it will only log.

## 0.3.11
- **[NetworkStorage]**: Added `writeRules` parameter to `NetworkStorage`. Allowing users to apply custom rules, to filter out records, that should not be synced to Network Storage.

## 0.3.10+1
### Bug Fixes
- **[SyncedState]**: Fixed a bug in `SyncedState` where subscriptions were not being added to the `_subscriptions` list, causing them to not be properly disposed and leading to potential memory leaks.

## 0.3.10

### New Features

- **[NetworkStorage]**: Added `streamAll` and `streamQuery` methods to support real-time data synchronization from Firestore.
- **[SyncManager]**: Added `listenAllFromNetwork` and `listenQueryFromNetwork` methods to subscribe to network changes and automatically synchronize with local storage.
- **[SyncedState]**: Added `keepAllInSync` and `keepQueryInSync` methods to simplify real-time UI updates from your state notifier.
- **[SyncedState]**: Added `dispose` method to cancel all active subscriptions and prevent memory leaks.

## 0.3.9
- **[SyncedState]** Added `stateOnly` option for `remove` and `clear` function, if set to true, the update will not be applied to local and network storage.

## 0.3.8
- **[SyncedState]** Added `stateOnly` option for `update` function, if set to true, the update will not be applied to local and network storage.

## 0.3.7

### New Features

- **[LocalStorage]**: Added `LocalStorage.disabled()` constructor and `disabled` parameter, mirroring `NetworkStorage.disabled`. When disabled, read operations (`getAll`) throw `PlatformException` with code `SYNC_OBJ_LOCAL_DISABLED`, and write operations (`update`, `delete`, `clear`) and `initialize()` are no-ops. Use this for network-only sync with no local persistence.

- **[SyncedState]**: `refresh()` now handles local read failure (e.g. when local storage is disabled) in the same way as network failure: a try/catch around `allFromStorage` sets state to empty on throw, then the existing try/catch around `fetchAndSyncFromNetwork` runs. Network-only setups work without special-casing in SyncManager.

---

## 0.3.6

### New Features

- **[LocalStorage]**: Added `initializeCallback` parameter that accepts an optional `Future<void> Function()` to be called after Hive box initialization.
- The `initialize()` method now calls the provided callback after completing the default initialization process.

---

## 0.3.5

### New Features

#### Custom Query Fetch Support
Added `getQueryFromNetwork` method for fetching data from network using custom Firestore queries.

- **[NetworkStorage]**: Enhanced `getQuery` method with optional `maxGetAllDocs` parameter to override the default limit per call.

- **[SyncManager]**: Added `getQueryFromNetwork(QueryFn<T> queryFn, [int? maxGetAllDocs])` method that fetches data using a custom query and optionally syncs with local storage.

- **[SyncedState]**: Added `getQueryFromNetwork(QueryFn<T> queryFn, {int? maxGetAllDocs})` method that fetches data using a custom query and updates state with new entries.

---

## 0.3.4
Added method `isInitialized` to both **[SyncManager]** and **[LocalStorage]** to check if they have been initialized.

## 0.3.3

### New Features

#### Batch Clear Support
Added `batchClear` method to perform clear operations within a Firestore write batch, complementing the existing `batchUpdate` and `batchRemove` operations.

- **[NetworkStorage]**: Added `writeBatchClear(WriteBatch batch, [String? docPath])` method:
  - For collection-based storage: fetches all documents and adds delete operations for each to the batch.
  - For non-collection-based storage: adds a delete operation for the document at the given path.
  - Note: This method is async as collection-based mode requires fetching document references.

- **[SyncManager]**: Added `batchClear(SyncBatch syncBatch)` method that queues clear operations on the network batch, waits for batch commit, then clears local storage.

- **[SyncedState]**: Added `batchClear(SyncBatch batch)` method that queues a clear operation in the batch and clears local state. **Note**: Call `batch.commit()` after all batch operations.

---

## 0.3.2

### New Features

#### Batch Operations Support
Added support for batch operations to perform multiple updates/deletes in a single Firestore write batch, improving performance and ensuring atomicity.

- **[SyncBatch]**: New class wrapping Firestore `WriteBatch` with a `Completer<void>` for async completion tracking.
  - `batch`: The underlying Firestore `WriteBatch`.
  - `completer`: A `Completer<void>` that completes when the batch is committed.
  - `commit()`: Commits the batch and completes the completer.

- **[SyncManager]**: Added batch operation methods:
  - `batchUpdate(Dataset<T> data, SyncBatch syncBatch)`: Performs a batch update operation using the provided `SyncBatch`. Updates network first, waits for batch commit, then updates local storage.
  - `batchRemove(Dataset<T> data, SyncBatch syncBatch)`: Performs a batch remove operation using the provided `SyncBatch`. Deletes from network first, waits for batch commit, then deletes from local storage.

- **[SyncedState]**: Added batch operation methods:
  - `batchUpdate(T value, SyncBatch batch)`: Queues a value update in the batch and updates local state immediately. **Note**: Call `batch.commit()` after all batch operations.
  - `batchRemoveAll(Iterable<String> ids, SyncBatch batch)`: Queues removal of multiple items by IDs in the batch and updates local state immediately.
---

## 0.3.1
Fixed bug of `syncLocalWithNetworkOnFetch` not working.

## 0.3.0

### Breaking Changes
- **[NetworkStorage]**: Renamed `defaultDocPath` parameter to `path` for better clarity and consistency.

### New Features

#### Collection-Based Storage Mode
Added support for collection-based storage in `NetworkStorage`, where each record is stored as a separate Firestore document instead of all records in a single document. This is useful for larger datasets or when you need to query individual records.

- New `collectionBased` parameter in `NetworkStorage` constructor to enable collection-based mode.
- New `NetworkStorageCollectionBasedConfig<T>` class for configuring collection-based storage:
  - `getAllEnabled`: Controls whether `getAll` is allowed for collection-based storage (default: `true`).
  - `maxGetAllDocs`: Maximum number of documents to fetch in `getAll` operations (default: `10`).
  - `defaultQuery`: Default query function (`QueryFn<T>`) for filtering/ordering documents.
- New `QueryFn<T>` typedef: `Query<T> Function(Query<T> colRef)` for custom query builders.
- New `getQuery` method in `NetworkStorage` for querying collection-based storage with custom Firestore queries.

#### Sync Improvements
- **[SyncManager]**: Added `syncLocalWithNetworkOnFetch` parameter (default: `true`) to control whether local storage should be synchronized with network data on fetch operations.
- **[SyncManager]**: Added new `fetchAndSyncFromNetwork` getter that fetches data from the network and optionally clears and updates local storage to match.
- **[SyncedState]**: The `refresh` method now uses `fetchAndSyncFromNetwork` instead of `allFromNetwork`, ensuring local storage stays in sync with network data.
- **[SyncedState]**: Changed `_params` from `late final` to `late` to allow reassignment/reconfiguration.

### Bug Fixes
- **[NetworkStorage.getAll]**: Now returns an empty `IMap<String, T>` if the Firestore document doesn't exist, instead of throwing a null error.
- **[NetworkStorage.writeBatchDelete]**: Fixed return type to properly return `void` instead of an unintended value.

### Internal Changes
- All `NetworkStorage` methods (`update`, `transactionUpdate`, `writeBatchUpdate`, `delete`, `transactionDelete`, `writeBatchDelete`, `clear`) now fully support collection-based mode.
- Collection-based operations use `WriteBatch` for efficient bulk operations.
- Added Firestore `withConverter` support for type-safe document operations in collection-based mode.

---

## 0.2.7
Updated dependencies

## 0.2.6
Added new `copyWith` method to [StdObjParams].

## 0.2.5
Removed flutter_riverpod dependency. This should not be a Breaking Change, since
none of the functionality actually depended on flutter_riverpod.

## 0.2.4
Added new `refresh` method in [SyncedState].

## 0.2.3
Fixed bug in [SyncedState]'s `clear` method, which now clears the state as well.

## 0.2.2
Fixed a bug in [SyncedState]'s `update` method, with sorting enabled, causing 
the newly added last element in the sorted dataset, to not be visible in state.

## 0.2.1
Fixed a bug in [SyncedState]'s `update` method, with sorting enabled.

## 0.2.0
[Breaking Change]: Replaced [hive_flutter] with [hive_ce_flutter].

## 0.1.0
[Breaking Change]: Replaced `Ref<Dataset<T>>` in `NotifierProviderRef<Dataset<T>>` in [SyncedState].

## 0.0.1

Contain important classes like [LocalStorage], [NetworkStorage], [StdObj], [StdObjParams], 
[SyncManager], [Synced] etc.

