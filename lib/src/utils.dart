import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

typedef Dataset<T> = IMap<String, T>;
typedef QueryFn<T> = Query<T> Function(Query<T> colRef);
