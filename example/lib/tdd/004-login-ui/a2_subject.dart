// GENERATED IMPLEMENTATION — `zfa tdd compose A2` (issue
// #642; spec 052-acceptance-make-composition: the acceptance subject is
// composed against the feature's green / entity-wired unit subjects by a
// generation-pipeline step, never by a wrapper or by hand).
//
// behavior_id: A2
// source_criterion: AC-2
// composed against: U2 (/home/z/my-project/zuraffa/example/lib/tdd/004-login-ui/u2_subject.dart)
// description: the error is reported to the caller
//
// This replaces the `zfa tdd gen` stub with the minimal composed
// implementation (spec 047 FR-005): the feature's unit subjects are the
// implementation anchors. An anchor marked [entity-wired] carries only
// the `zfa tdd wire` wiring so far (issue #923) — the composed scenario's
// real green transition lands when those unit subjects are filled with
// business logic in later cycles. Extend the body with real behavior in
// later cycles — the paired test file is immutable (044 ownership).
//
// The subject name is derived from the behavior id (`subject_a2`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:example/tdd/004-login-ui/u2_subject.dart' as anchor0;

/// Subject for behavior A2, composed against the
/// feature's unit subject anchors by the generation pipeline.
void subject_a2() {
  // Composition anchor: references the feature's green / entity-wired unit
  // subjects this behavior builds on.
  // ignore: unused_local_variable
  final composedUnitAnchors = <Function>[anchor0.subject_u2];
}
