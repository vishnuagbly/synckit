import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'objects/std_obj.dart';
import 'utils.dart';

class LocalStorage<T> {
  final String boxName;

  const LocalStorage(this.boxName);

  @override
  int get hashCode => boxName.hashCode;

  @override
  bool operator ==(Object other) =>
      (other is LocalStorage) && other.boxName == boxName;

  Dataset<T> getAll(StdObjParams<T> params) {
    return box
        .toMap()
        .map((key, value) => MapEntry(key as String,
            params.fromJson(Map<String, dynamic>.from(jsonDecode(value)))))
        .toIMap();
  }

  Future<void> update(IMap<String, T> data, StdObjParams<T> params) async {
    List<Future<void>> futures = [];
    for (final entry in data.entries) {
      futures.add(box.put(entry.key, jsonEncode(params.toJson(entry.value))));
    }
    await Future.wait(futures);
  }

  Future<void> delete(Dataset<T> data, StdObjParams<T> params) async {
    final ids = data.keys;
    List<Future<void>> futures = [];
    for (final id in ids) {
      futures.add(box.delete(id));
    }
    await Future.wait(futures);
  }

  Future<void> clear() async {
    await box.clear();
  }

  Box<String> get box => Hive.box<String>(boxName);

  Future<void> initialize() => _initialize(boxName);

  static Future<void> _initialize(String boxName) async {
    if (_isInitialized(boxName)) return;

    await Hive.openBox<String>(boxName);
  }

  bool get isInitialized => _isInitialized(boxName);

  static bool _isInitialized(String boxName) {
    return Hive.isBoxOpen(boxName);
  }
}
