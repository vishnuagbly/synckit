import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:synckit/synckit.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
abstract class Task with _$Task implements StdObj {
  const Task._();

  const factory Task({
    required String id,
    required String title,
    @Default('') String description,
    @Default(false) bool isCompleted,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  factory Task.create({
    required String title,
    String description = '',
  }) {
    final now = DateTime.now();
    return Task(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      description: description,
      createdAt: now,
    );
  }

  Task copyWithUpdatedAt() => copyWith(updatedAt: DateTime.now());
}

