import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'objects/std_obj.dart';
import 'utils.dart';

class LocalStorage<T> {
  final String boxName;
  final bool disabled;
  final Future<void> Function()? initializeCallback;

  const LocalStorage.disabled()
      : boxName = '',
        disabled = true,
        initializeCallback = null;

  const LocalStorage(this.boxName,
      {this.disabled = false, this.initializeCallback});

  @override
  int get hashCode => disabled ? 0 : boxName.hashCode;

  @override
  bool operator ==(Object other) =>
      other is LocalStorage<T> &&
      other.disabled == disabled &&
      (disabled || other.boxName == boxName);

  Dataset<T> getAll(StdObjParams<T> params) {
    _assertDisabled();
    return box
        .toMap()
        .map((key, value) => MapEntry(key as String,
            params.fromJson(Map<String, dynamic>.from(jsonDecode(value)))))
        .toIMap();
  }

  Future<void> update(IMap<String, T> data, StdObjParams<T> params) async {
    if (disabled) return;
    List<Future<void>> futures = [];
    for (final entry in data.entries) {
      futures.add(box.put(entry.key, jsonEncode(params.toJson(entry.value))));
    }
    await Future.wait(futures);
  }

  Future<void> delete(Dataset<T> data, StdObjParams<T> params) async {
    if (disabled) return;
    final ids = data.keys;
    List<Future<void>> futures = [];
    for (final id in ids) {
      futures.add(box.delete(id));
    }
    await Future.wait(futures);
  }

  Future<void> clear() async {
    if (disabled) return;
    await box.clear();
  }

  Box<String> get box {
    _assertDisabled();
    return Hive.box<String>(boxName);
  }

  void _assertDisabled() {
    if (disabled) throw PlatformException(code: 'SYNC_OBJ_LOCAL_DISABLED');
  }

  Future<void> initialize() async {
    if (disabled) return;
    await _initialize(boxName);
    return initializeCallback?.call();
  }

  static Future<void> _initialize(String boxName) async {
    if (_isInitialized(boxName)) return;

    await Hive.openBox<String>(boxName);
  }

  bool get isInitialized => disabled || _isInitialized(boxName);

  static bool _isInitialized(String boxName) {
    return Hive.isBoxOpen(boxName);
  }
}
