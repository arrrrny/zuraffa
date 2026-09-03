// GENERATED IMPLEMENTATION — `zfa tdd wire A2` (bug
// #610; epic 045 precondition 5: the subject is wired by a
// generation-pipeline step, never by a wrapper or by hand).
//
// behavior_id: A2
// source_criterion: AC-2
// entity: TodoStats
// description: create entity TodoStats with total, active, completed.
//
// This replaces the `zfa tdd gen` stub with the minimal wired
// implementation (spec 047 FR-005): the generated entity TodoStats is
// the implementation anchor. Extend the body with real behavior in
// later cycles — the paired test file is immutable (044 ownership).
library;
// ignore_for_file: non_constant_identifier_names

import 'package:todo_tdd/src/domain/entities/todo_stats/todo_stats.dart';

/// Subject for behavior A2, wired to entity
/// TodoStats by the generation pipeline.
void subject_a2() {
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = TodoStats;
}
