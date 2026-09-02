// GENERATED IMPLEMENTATION — `zfa tdd wire A1` (bug
// #610; epic 045 precondition 5: the subject is wired by a
// generation-pipeline step, never by a wrapper or by hand).
//
// behavior_id: A1
// source_criterion: AC-1
// entity: Todo
// description: create entity Todo with id, title, description, isCompleted, priority, tags, createdAt, completedAt.
//
// This replaces the `zfa tdd gen` stub with the minimal wired
// implementation (spec 047 FR-005): the generated entity Todo is
// the implementation anchor. Extend the body with real behavior in
// later cycles — the paired test file is immutable (044 ownership).
library;

import 'package:todo_tdd/src/domain/entities/todo/todo.dart';

/// Subject for behavior A1, wired to entity
/// Todo by the generation pipeline.
void subject_a1() {
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = Todo;
}
