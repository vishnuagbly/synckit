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

