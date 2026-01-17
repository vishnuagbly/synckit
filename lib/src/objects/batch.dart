import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class SyncBatch {
  final WriteBatch batch;
  final Completer<void> completer;

  SyncBatch()
      : batch = FirebaseFirestore.instance.batch(),
        completer = Completer<void>();

  Future<void> commit() async {
    await batch.commit();
    completer.complete();
  }
}
