import 'package:zorphy_annotation/zorphy.dart';

part 'todo.zorphy.dart';

/// Priority levels for todo items.
///
/// Zorphy supports enums as entity fields — the generated code
/// includes enum values in [TodoFields] descriptors, [TodoPatch],
/// and [compareTo] diff tracking.
enum TodoPriority { low, medium, high }

/// Rich todo entity showcasing zorphy v2.1 full-preset generation.
///
/// Annotations explained:
/// - [ZorphyPreset.full] — generates constructor, copyWith, copyWithFn,
///   copyWithNamed, Patch API, Field descriptors, compareTo, and
///   property helpers in a single `.zorphy.dart` part file.
/// - [generateCompareTo] — adds a `compareToTodo(Todo other)` extension
///   that returns a map of changed fields (useful for audit logs or
///   undo/redo stacks).
///
/// Field types demonstrated:
/// - `int id` — primary key, used with [Eq] filter and [DeleteParams].
/// - `String title` / `String description` — text fields with property
///   helpers (`hasTitle`, `noDescription`, etc.).
/// - `bool isCompleted` — toggle field, patched via [TodoPatch].
/// - `TodoPriority priority` — enum field, filterable with
///   `TodoFields.priority.eq(TodoPriority.high)`.
/// - `List<String> tags` — collection field with `hasTags` / `noTags`
///   helpers.
/// - `DateTime createdAt` / `DateTime completedAt` — lifecycle timestamps.
@Zorphy(
  preset: ZorphyPreset.full,
  generateCompareTo: true,
)
abstract class $Todo {
  int get id;
  String get title;
  String get description;
  bool get isCompleted;
  TodoPriority get priority;
  List<String> get tags;
  DateTime get createdAt;
  DateTime get completedAt;
}
