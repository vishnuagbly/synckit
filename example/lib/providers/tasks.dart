import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synckit/synckit.dart';

import '../objects/task.dart';

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
  /// Replace this with your actual user ID from authentication
  static String? userId;

  @override
  Dataset<Task> build() {
    final manager = SyncManager<Task>.fromStdObj(
      fromJson: Task.fromJson,
      storage: const LocalStorage('tasks'),
      network: userId != null
          ? NetworkStorage('users/$userId/data/tasks')
          : const NetworkStorage.disabled(),
    );

    return initialize(
      SyncConfig(
        manager: manager,
        sortConfig: const SortConfig(
          isSorted: true,
          ascending: false,
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

