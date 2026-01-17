import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';

import 'std_obj.dart';
import 'synced.dart';

typedef QueryFn<T> = Query<T> Function(Query<T> colRef);

class NetworkStorageCollectionBasedConfig<T> {
  final bool getAllEnabled;
  final int maxGetAllDocs;
  final QueryFn<T>? _defaultQuery;

  const NetworkStorageCollectionBasedConfig({
    this.getAllEnabled = true,
    this.maxGetAllDocs = 10,
    QueryFn<T>? defaultQuery,
  }) : _defaultQuery = defaultQuery;

  QueryFn<T> get defaultQuery =>
      _defaultQuery ??
      ((query) {
        // By default, no filtering or ordering is applied.
        return query;
      });
}

class NetworkStorage<T> {
  final String path;
  final bool disabled;

  /// If true, the data will be stored in a collection-based format,
  /// i.e for each record there will be a separate document.
  ///
  /// NOTE:- This might lead to higher read/write costs in Firestore.
  final bool collectionBased;
  final NetworkStorageCollectionBasedConfig<T> collectionBasedConfig;

  const NetworkStorage.disabled()
      : path = '',
        disabled = true,
        collectionBased = false,
        collectionBasedConfig = const NetworkStorageCollectionBasedConfig();

  const NetworkStorage(
    this.path, {
    this.disabled = false,
    this.collectionBased = false,
    this.collectionBasedConfig = const NetworkStorageCollectionBasedConfig(),
  });

  Future<IMap<String, T>> getAll(StdObjParams<T> params,
      [String? docPath]) async {
    _assertDisabled();
    if (collectionBased) {
      if (!(collectionBasedConfig.getAllEnabled)) {
        throw PlatformException(
          code: 'GET_ALL_DISABLED',
          message:
              'NetworkStorage.getAll called for collection-based storage, but getAll is disabled in config.',
          details: 'Path: $path',
        );
      }

      return getQuery(params);
    }

    try {
      final docRef = FirebaseFirestore.instance.doc(docPath ?? path);
      final data = (await docRef.get()).data();
      if (data == null) {
        return IMap<String, T>();
      }

      return data
          .map((key, value) => MapEntry(key, params.fromJson(value)))
          .toIMap();
    } catch (err) {
      throw PlatformException(
        code: 'CANNOT_FETCH',
        message: 'Cannot fetch object: $T from Network.',
      );
    }
  }

  /// Only enabled for collection-based storage.
  Future<IMap<String, T>> getQuery(StdObjParams<T> params,
      [QueryFn<T>? query]) {
    _assertDisabled();
    if (!collectionBased) {
      throw PlatformException(
        code: 'COLLECTION_BASED_STORAGE_DISABLED',
        message: 'Querying is only supported for collection-based storage.',
      );
    }

    Query<T> colRef =
        FirebaseFirestore.instance.collection(path).withConverter<T>(
              fromFirestore: (snap, _) => params.fromJson(snap.data()!),
              toFirestore: (obj, _) => params.toJson(obj),
            );

    colRef = (query ?? collectionBasedConfig.defaultQuery)(colRef);
    if (collectionBasedConfig.maxGetAllDocs > 0) {
      colRef = colRef.limit(collectionBasedConfig.maxGetAllDocs);
    }

    return colRef.get().then((querySnapshot) {
      final dataMap = {
        for (final doc in querySnapshot.docs) doc.id: doc.data(),
      };
      return dataMap.toIMap();
    });
  }

  Future<void> update(Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) async {
    if (disabled) return;

    if (collectionBased) {
      final batch = FirebaseFirestore.instance.batch();
      writeBatchUpdate(batch, data, params, docPath);
      return batch.commit();
    }

    final (docRef, setData, setOptions) =
        _getUpdateParams(data, params, docPath);
    return docRef.set(setData, setOptions);
  }

  Transaction transactionUpdate(
      Transaction transaction, Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) {
    if (disabled) return transaction;

    if (collectionBased) {
      final colRef = FirebaseFirestore.instance.collection(docPath ?? path);
      for (final entry in data.entries) {
        final docRef = colRef.doc(entry.key);
        transaction.set(
            docRef, params.toJson(entry.value), SetOptions(merge: true));
      }
      return transaction;
    }

    final (docRef, setData, setOptions) =
        _getUpdateParams(data, params, docPath);
    return transaction.set(docRef, setData, setOptions);
  }

  void writeBatchUpdate(
      WriteBatch batch, Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) {
    if (disabled) return;

    if (collectionBased) {
      final colRef = FirebaseFirestore.instance.collection(docPath ?? path);
      for (final entry in data.entries) {
        final docRef = colRef.doc(entry.key);
        batch.set(docRef, params.toJson(entry.value), SetOptions(merge: true));
      }
      return;
    }

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

    final docRef = FirebaseFirestore.instance.doc(docPath ?? path);
    final setData =
        data.unlock.map((key, value) => MapEntry(key, params.toJson(value)));
    final setOptions = SetOptions(merge: true);
    return (docRef, setData, setOptions);
  }

  Future<void> delete(Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) async {
    if (disabled) return;

    if (collectionBased) {
      final batch = FirebaseFirestore.instance.batch();
      writeBatchDelete(batch, data, params, docPath);
      return batch.commit();
    }

    final (docRef, deleteData) = _getDeleteParams(data, params, docPath);
    return docRef.update(deleteData);
  }

  Transaction transactionDelete(
      Transaction transaction, Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) {
    if (disabled) return transaction;

    if (collectionBased) {
      final colRef = FirebaseFirestore.instance.collection(docPath ?? path);
      for (final id in data.keys) {
        transaction.delete(colRef.doc(id));
      }
      return transaction;
    }

    final (docRef, deleteData) = _getDeleteParams(data, params, docPath);
    return transaction.update(docRef, deleteData);
  }

  void writeBatchDelete(
      WriteBatch batch, Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) {
    if (disabled) return;

    if (collectionBased) {
      final colRef = FirebaseFirestore.instance.collection(docPath ?? path);
      for (final id in data.keys) {
        batch.delete(colRef.doc(id));
      }
      return;
    }

    final (docRef, deleteData) = _getDeleteParams(data, params, docPath);
    batch.update(docRef, deleteData);
  }

  (DocumentReference<Map<String, dynamic>>, Map<String, FieldValue>)
      _getDeleteParams(Dataset<T> data, StdObjParams<T> params,
          [String? docPath]) {
    _assertDisabled();

    final ids = data.keys;
    final docRef = FirebaseFirestore.instance.doc(docPath ?? path);
    final deleteData = {
      for (final id in ids) id: FieldValue.delete(),
    };
    return (docRef, deleteData);
  }

  Future<void> clear([String? docPath]) async {
    if (disabled) return;

    if (collectionBased) {
      final colRef = FirebaseFirestore.instance.collection(docPath ?? path);
      final snapshot = await colRef.get();
      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      return batch.commit();
    }

    final docRef = FirebaseFirestore.instance.doc(docPath ?? path);
    return docRef.delete();
  }

  void _assertDisabled() {
    if (disabled) throw PlatformException(code: 'SYNC_OBJ_NETWORK_DISABLED');
  }
}
