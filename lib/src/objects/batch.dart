import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A Firestore [WriteBatch] plus the local work that runs after it commits.
///
/// One [SyncBatch] may be passed to notifiers of different types. Each manager
/// appends to the same [WriteBatch].
///
/// Await every `SyncedState.batchUpdate`, `SyncedState.batchRemoveAll`, and
/// `SyncedState.batchClear` before [commit].
///
/// Queue at most one write per Firestore document path. A second `set` or
/// `delete` of the same path in one [WriteBatch] fails the whole commit.
/// Callers coalesce to the final object per id before queueing.
///
/// [commit] order stays: Firestore, then Hive callbacks (`Future.wait`), then
/// state callbacks in registration order.
///
/// If [WriteBatch.commit] throws, Hive callbacks and state callbacks do not
/// run. Providers stay as they were.
///
/// Hive is still one box per `LocalStorage`. A failure in a Hive callback
/// happens after Firestore has committed. The network remains the source of
/// truth, and a later fetch repairs local storage.
///
/// State callbacks must not run before [commit]. Listeners see the batch only
/// after Firestore succeeds.
class SyncBatch {
  WriteBatch? _batch;
  final List<Future Function()> asyncCallbacks;
  final List<Function()> syncCallbacks;
  final Future<void> Function()? _commitWritesForTest;

  /// The Firestore batch each manager appends to.
  WriteBatch get batch {
    final writeBatch = _batch;
    if (writeBatch == null) {
      throw StateError(
        'SyncBatch.forTest has no Firestore WriteBatch. '
        'Use SyncBatch() to queue Firestore writes.',
      );
    }
    return writeBatch;
  }

  SyncBatch()
      : asyncCallbacks = [],
        syncCallbacks = [],
        _commitWritesForTest = null {
    _batch = FirebaseFirestore.instance.batch();
  }

  /// Stands in for [WriteBatch.commit] so tests can run [commit] without a
  /// Firestore project. [batch] is unavailable on this instance.
  @visibleForTesting
  SyncBatch.forTest({required Future<void> Function() commitWrites})
      : asyncCallbacks = [],
        syncCallbacks = [],
        _commitWritesForTest = commitWrites;

  Future<void> commit() async {
    final commitWrites = _commitWritesForTest;
    if (commitWrites != null) {
      await commitWrites();
    } else {
      await batch.commit();
    }
    await Future.wait(asyncCallbacks.map((callback) => callback()));
    for (final callback in syncCallbacks) {
      callback();
    }
  }

  void addAsyncCallback(Future Function() callback) {
    asyncCallbacks.add(callback);
  }

  void addSyncCallback(Function() callback) {
    syncCallbacks.add(callback);
  }
}
