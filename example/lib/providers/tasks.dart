import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synckit/synckit.dart';

import '../objects/task.dart';
import 'settings.dart';

part 'tasks.g.dart';

/// Example Riverpod provider demonstrating synckit usage.
///
/// This provider syncs Task objects between:
/// - Local storage (Hive) at box name 'tasks'
/// - Network storage (Firestore) at 'users/{userId}/data/tasks'
///
/// Usage:
/// ```dart
/// final tasksAsync = ref.watch(tasksProvider);
/// tasksAsync.when(
///   data: (tasks) => ...,
///   loading: () => ...,
///   error: (e, st) => ...,
/// );
/// ```
@riverpod
class Tasks extends _$Tasks with SyncedState<Task> {
  @override
  Dataset<Task> build() {
    final settings = ref.watch(collectionSettingsProvider);

    final NetworkStorage<Task> network;
    if (settings.enabled) {
      // Collection-based mode: each task is a separate document
      network = NetworkStorage(
        'tasks',
        collectionBased: true,
        collectionBasedConfig: NetworkStorageCollectionBasedConfig(
          getAllEnabled: settings.getAllEnabled,
          maxGetAllDocs: settings.maxGetAllDocs,
          defaultQuery: (query) => query.orderBy('createdAt', descending: true),
        ),
      );
    } else {
      // Document-based mode: all tasks in a single document
      network = const NetworkStorage('data/tasks');
    }

    final manager = SyncManager<Task>.fromStdObj(
      fromJson: Task.fromJson,
      storage: const LocalStorage('tasks'),
      network: network,
    );

    return initialize(
      SyncConfig(
        manager: manager,
        sortConfig: SortConfig(
          isSorted: true,
          ascending: false,
          comparator: (a, b) =>
              (a.updatedAt ?? a.createdAt).compareTo(b.updatedAt ?? b.createdAt),
        ),
      ),
    );
  }

  /// Add a new task
  Future<void> addTask(String title, {String description = ''}) async {
    final task = Task.create(title: title, description: description);
    await update(task);
  }

  /// Toggle task completion status
  Future<void> toggleComplete(Task task) async {
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      updatedAt: DateTime.now(),
    );
    await update(updated);
  }

  /// Update task details
  Future<void> updateTask(Task task) async {
    await update(task.copyWithUpdatedAt());
  }

  /// Delete a task by ID
  Future<void> deleteTask(String id) async {
    await remove(id);
  }
}

