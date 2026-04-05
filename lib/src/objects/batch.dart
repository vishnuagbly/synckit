import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class SyncBatch {
  final WriteBatch batch;
  final List<Future Function()> asyncCallbacks;
  final List<Function()> syncCallbacks;

  SyncBatch()
      : batch = FirebaseFirestore.instance.batch(),
        asyncCallbacks = [],
        syncCallbacks = [];

  Future<void> commit() async {
    await batch.commit();
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
