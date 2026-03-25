import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';

import 'objects/std_obj.dart';
import 'utils.dart';

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
  final GetOptions? defaultGetOptions;

  /// Use this to filter out data from the stream, that should not be synced
  /// to the network.
  final Dataset<T> Function(Dataset<T> data)? writeRules;

  const NetworkStorage.disabled()
      : path = '',
        disabled = true,
        collectionBased = false,
        writeRules = null,
        defaultGetOptions = null,
        collectionBasedConfig = const NetworkStorageCollectionBasedConfig();

  const NetworkStorage(
    this.path, {
    this.disabled = false,
    this.collectionBased = false,
    this.writeRules,
    this.collectionBasedConfig = const NetworkStorageCollectionBasedConfig(),
    this.defaultGetOptions = const GetOptions(source: Source.server),
  });

  Stream<Dataset<T>> streamAll(StdObjParams<T> params) {
    _assertDisabled();
    if (collectionBased) {
      if (!(collectionBasedConfig.getAllEnabled)) {
        throw PlatformException(
          code: 'GET_ALL_DISABLED',
          message:
              'Listening to all objects is only supported for collection-based '
              'storage when getAllEnabled is true in config.',
          details: 'Path: $path',
        );
      }
      return streamQuery(params);
    }

    final docRef = FirebaseFirestore.instance.doc(path);
    return docRef
        .snapshots()
        .map((snapshot) => _docSnapshotToDataset(snapshot, params));
  }

  Stream<Dataset<T>> streamQuery(StdObjParams<T> params,
      [QueryFn<T>? query, int? maxGetAllDocs]) {
    _assertDisabled();
    if (!collectionBased) {
      throw PlatformException(
        code: 'COLLECTION_BASED_STORAGE_DISABLED',
        message: 'Listening a query is only supported for collection-based '
            'storage.',
      );
    }

    return _genColRef(params, query, maxGetAllDocs)
        .snapshots()
        .map(_querySnapshotToDataset);
  }

  Future<IMap<String, T>> getAll(StdObjParams<T> params,
      [QueryFn<T>? query, String? docPath, GetOptions? getOptions]) async {
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

      return getQuery(params, query, null, getOptions);
    }

    try {
      final docRef = FirebaseFirestore.instance.doc(docPath ?? path);
      return _docSnapshotToDataset(
          (await docRef.get(getOptions ?? defaultGetOptions)), params);
    } catch (err) {
      throw PlatformException(
        code: 'CANNOT_FETCH',
        message: 'Cannot fetch object: $T from Network.',
      );
    }
  }

  Dataset<T> _docSnapshotToDataset(
      DocumentSnapshot<Map<String, dynamic>> snapshot, StdObjParams<T> params) {
    final data = snapshot.data();
    if (data == null) {
      return IMap<String, T>();
    }

    return data
        .map((key, value) => MapEntry(key, params.fromJson(value)))
        .toIMap();
  }

  /// Only enabled for collection-based storage.
  ///
  /// [maxGetAllDocs] limits the maximum number of documents to fetch.
  /// If not provided, it defaults to the value in [collectionBasedConfig].
  Future<Dataset<T>> getQuery(StdObjParams<T> params,
      [QueryFn<T>? query, int? maxGetAllDocs, GetOptions? getOptions]) async {
    _assertDisabled();
    if (!collectionBased) {
      throw PlatformException(
        code: 'COLLECTION_BASED_STORAGE_DISABLED',
        message: 'Querying is only supported for collection-based storage.',
      );
    }

    try {
      return _genColRef(params, query, maxGetAllDocs)
          .get(getOptions ?? defaultGetOptions)
          .then(_querySnapshotToDataset);
    } catch (err) {
      if (err is FirebaseException) {
        if (err.code == 'unavailable') {
          throw PlatformException(
              code: 'CONN_FAILURE',
              message:
                  'Cannot connect to our servers. Try checking your internet connection.');
        }
      }
      rethrow;
    }
  }

  Query<T> _genColRef(StdObjParams<T> params,
      [QueryFn<T>? query, int? maxGetAllDocs]) {
    Query<T> colRef =
        FirebaseFirestore.instance.collection(path).withConverter<T>(
              fromFirestore: (snap, _) => params.fromJson(snap.data()!),
              toFirestore: (obj, _) => params.toJson(obj),
            );

    colRef = (query ?? collectionBasedConfig.defaultQuery)(colRef);

    maxGetAllDocs ??= collectionBasedConfig.maxGetAllDocs;
    if (maxGetAllDocs > 0) {
      colRef = colRef.limit(maxGetAllDocs);
    }

    return colRef;
  }

  Dataset<T> _querySnapshotToDataset(QuerySnapshot<T> snapshot) {
    final dataMap = {
      for (final doc in snapshot.docs) doc.id: doc.data(),
    };
    return dataMap.toIMap();
  }

  Future<void> update(Dataset<T> data, StdObjParams<T> params,
      [String? docPath]) async {
    if (disabled) return;
    data = _applyWriteRules(data);
    if (data.isEmpty) return;

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
    data = _applyWriteRules(data);
    if (data.isEmpty) return transaction;

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
    data = _applyWriteRules(data);
    if (data.isEmpty) return;

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

  Dataset<T> _applyWriteRules(Dataset<T> data) {
    _logIfEmptyData(data);
    if (writeRules == null || data.isEmpty) return data;
    data = writeRules!(data);
    if (data.isEmpty) {
      log(
          'Warning: All data was filtered out by writeRules for NetworkStorage at path: $path. '
          'This might be intentional, but it could also indicate an issue with the write rules.',
          name: 'NetworkStorage');
    }
    return data;
  }

  void _logIfEmptyData(Dataset<T> data) {
    if (data.isEmpty) {
      log(
          'Warning: Attempting to write an empty dataset to NetworkStorage at path: $path. '
          'This might be intentional, but it could also indicate an issue with the data.',
          name: 'NetworkStorage');
    }
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

  /// Adds clear operations to the provided [WriteBatch].
  ///
  /// For collection-based storage, this fetches all documents and adds delete
  /// operations for each to the batch.
  /// For non-collection-based storage, this adds a delete operation for the
  /// document at the given path.
  ///
  /// NOTE: This method is async for collection-based storage as it needs to
  /// fetch document references before adding them to the batch.
  Future<void> writeBatchClear(WriteBatch batch, [String? path]) async {
    if (disabled) return;

    if (collectionBased) {
      final colRef = FirebaseFirestore.instance.collection(path ?? this.path);
      final snapshot = await colRef.get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      return;
    }

    final docRef = FirebaseFirestore.instance.doc(path ?? this.path);
    batch.delete(docRef);
  }

  void _assertDisabled() {
    if (disabled) throw PlatformException(code: 'SYNC_OBJ_NETWORK_DISABLED');
  }
}
