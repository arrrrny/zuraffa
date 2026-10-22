// GENERATED IMPLEMENTATION — `zfa tdd compose A11` (issue
// #642; spec 052-acceptance-make-composition: the acceptance subject is
// composed against the feature's green / entity-wired unit subjects by a
// generation-pipeline step, never by a wrapper or by hand).
//
// behavior_id: A11
// source_criterion: AC-11
// composed against: U1 (lib/tdd/072-dependency-mocks/u1_subject.dart), U2 (lib/tdd/072-dependency-mocks/u2_subject.dart), U3 (lib/tdd/072-dependency-mocks/u3_subject.dart), U4 (lib/tdd/072-dependency-mocks/u4_subject.dart), U5 (lib/tdd/072-dependency-mocks/u5_subject.dart), U6 (lib/tdd/072-dependency-mocks/u6_subject.dart), U7 (lib/tdd/072-dependency-mocks/u7_subject.dart), U8 (lib/tdd/072-dependency-mocks/u8_subject.dart), U9 (lib/tdd/072-dependency-mocks/u9_subject.dart), U10 (lib/tdd/072-dependency-mocks/u10_subject.dart)
// description: their relative order equals their declaration order in the spec, stably across runs.
//
// This replaces the `zfa tdd gen` stub with the minimal composed
// implementation (spec 047 FR-005): the feature's unit subjects are the
// implementation anchors. An anchor marked [entity-wired] carries only
// the `zfa tdd wire` wiring so far (issue #923) — the composed scenario's
// real green transition lands when those unit subjects are filled with
// business logic in later cycles. Extend the body with real behavior in
// later cycles — the paired test file is immutable (044 ownership).
//
// The subject name is derived from the behavior id (`subject_a11`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:zuraffa/tdd/072-dependency-mocks/u1_subject.dart' as anchor0;
import 'package:zuraffa/tdd/072-dependency-mocks/u2_subject.dart' as anchor1;
import 'package:zuraffa/tdd/072-dependency-mocks/u3_subject.dart' as anchor2;
import 'package:zuraffa/tdd/072-dependency-mocks/u4_subject.dart' as anchor3;
import 'package:zuraffa/tdd/072-dependency-mocks/u5_subject.dart' as anchor4;
import 'package:zuraffa/tdd/072-dependency-mocks/u6_subject.dart' as anchor5;
import 'package:zuraffa/tdd/072-dependency-mocks/u7_subject.dart' as anchor6;
import 'package:zuraffa/tdd/072-dependency-mocks/u8_subject.dart' as anchor7;
import 'package:zuraffa/tdd/072-dependency-mocks/u9_subject.dart' as anchor8;
import 'package:zuraffa/tdd/072-dependency-mocks/u10_subject.dart' as anchor9;

/// Subject for behavior A11, composed against the
/// feature's unit subject anchors by the generation pipeline.
void subject_a11() {
  // Composition anchor: references the feature's green / entity-wired unit
  // subjects this behavior builds on.
  // ignore: unused_local_variable
  final composedUnitAnchors = <Function>[
    anchor0.subject_u1,
    anchor1.subject_u2,
    anchor2.subject_u3,
    anchor3.subject_u4,
    anchor4.subject_u5,
    anchor5.subject_u6,
    anchor6.subject_u7,
    anchor7.subject_u8,
    anchor8.subject_u9,
    anchor9.subject_u10,
  ];
}
