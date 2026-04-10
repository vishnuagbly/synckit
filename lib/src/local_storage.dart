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
  static bool _recording = true;
  static final Map<String, LocalStorage> _instances = {};

  static bool get recording => _recording;

  static void enableRecording() {
    _recording = true;
    _instances.clear();
  }

  static void disableRecording() {
    _recording = false;
    _instances.clear();
  }

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
    return deleteFromIds(data.keys);
  }

  Future<void> deleteFromIds(Iterable<String> ids) async {
    if (disabled) return;
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
    if (_recording) _instances[boxName] = this;
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

  static Future<void> clearAll() {
    List<Future<void>> futures = [];
    for (final instance in _instances.values) {
      if (!instance.disabled) {
        futures.add(instance.clear());
      }
    }
    return Future.wait(futures);
  }
}
