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

