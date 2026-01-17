import 'dart:async';

import '../sync_manager.dart';
import '../synced.dart';
import '../utils.dart';
import 'sort_config.dart';

class SyncConfig<T> {
  final Dataset<T>? initialState;
  final SyncManager<T> manager;
  final SortConfig<T> sortConfig;
  Future Function(Dataset<T> state, SyncedState<T> obj)? initializeCallback;
  final Completer<void> completer;

  SyncConfig({
    this.initialState,
    required this.manager,
    this.sortConfig = const SortConfig(),
    this.initializeCallback,
  }) : completer = Completer<void>();

  @override
  bool operator ==(Object other) {
    return other is SyncConfig &&
        other.initialState == initialState &&
        other.sortConfig == sortConfig &&
        other.manager == manager;
  }

  @override
  int get hashCode => Object.hash(initialState, sortConfig, manager);
}
