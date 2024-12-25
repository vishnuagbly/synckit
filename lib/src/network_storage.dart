import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';

import 'std_obj.dart';
import 'synced.dart';

class NetworkStorage<T> {
  final String defaultDocPath;
  final bool disabled;

  const NetworkStorage.disabled()
      : defaultDocPath = '',
        disabled = true;

  const NetworkStorage(
    this.defaultDocPath, {
    this.disabled = false,
  });

  Future<IMap<String, T>> getAll(StdObjParams<T> params,
      [String? docPath]) async {
    _assertDisabled();

    try {
      final docRef = FirebaseFirestore.instance.doc(docPath ?? defaultDocPath);
      return (await docRef.get())
          .data()!
          .map((key, value) => MapEntry(key, params.fromJson(value)))
          .toIMap();
    } catch (err) {
      throw PlatformException(
        code: 'CANNOT_FETCH',
        message: 'Cannot fetch object: $T from Network.',
      );
    }
  }

  Future<void> update(Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) async {
    if (disabled) return;

    final (docRef, setData, setOptions) =
        _getUpdateParams(data, params, docPath);
    return docRef.set(setData, setOptions);
  }

  Transaction transactionUpdate(
      Transaction transaction, Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) {
    if (disabled) return transaction;

    final (docRef, setData, setOptions) =
        _getUpdateParams(data, params, docPath);
    return transaction.set(docRef, setData, setOptions);
  }

  void writeBatchUpdate(
      WriteBatch batch, Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) {
    if (disabled) return;

    final (docRef, setData, setOptions) =
        _getUpdateParams(data, params, docPath);
    batch.set(docRef, setData, setOptions);
  }

  (
    DocumentReference<Map<String, dynamic>>,
    Map<String, Map<String, dynamic>>,
    SetOptions
  ) _getUpdateParams(IMap<String, T> data, StdObjParams<T> params,
      [String? docPath]) {
    _assertDisabled();

    final docRef = FirebaseFirestore.instance.doc(docPath ?? defaultDocPath);
    final setData =
        data.unlock.map((key, value) => MapEntry(key, params.toJson(value)));
    final setOptions = SetOptions(merge: true);
    return (docRef, setData, setOptions);
  }

  Future<void> delete(Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) async {
    if (disabled) return;

    final (docRef, deleteData) = _getDeleteParams(data, params, docPath);
    return docRef.update(deleteData);
  }

  Transaction transactionDelete(
      Transaction transaction, Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) {
    if (disabled) return transaction;

    final (docRef, deleteData) = _getDeleteParams(data, params, docPath);
    return transaction.update(docRef, deleteData);
  }

  void writeBatchDelete(
      WriteBatch batch, Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) {
    if (disabled) return;

    final (docRef, deleteData) = _getDeleteParams(data, params, docPath);
    return batch.update(docRef, deleteData);
  }

  (DocumentReference<Map<String, dynamic>>, Map<String, FieldValue>)
      _getDeleteParams(Dataset<T> data, StdObjParams<T> params,
          [String? docPath]) {
    _assertDisabled();

    final ids = data.keys;
    final docRef = FirebaseFirestore.instance.doc(docPath ?? defaultDocPath);
    final deleteData = {
      for (final id in ids) id: FieldValue.delete(),
    };
    return (docRef, deleteData);
  }

  Future<void> clear([String? docPath]) async {
    if (disabled) return;

    final docRef = FirebaseFirestore.instance.doc(docPath ?? defaultDocPath);
    return docRef.delete();
  }

  void _assertDisabled() {
    if (disabled) throw PlatformException(code: 'SYNC_OBJ_NETWORK_DISABLED');
  }
}
