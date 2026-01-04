// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tasksHash() => r'8778e934cd3d4ff883a2e284981e6fc300b7de45';

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
///
/// Copied from [Tasks].
@ProviderFor(Tasks)
final tasksProvider =
    AutoDisposeNotifierProvider<Tasks, Dataset<Task>>.internal(
  Tasks.new,
  name: r'tasksProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$tasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Tasks = AutoDisposeNotifier<Dataset<Task>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
