// GENERATED — `zfa tdd gen U1` (spec 044-test-tdd-generation),
// implemented at GREEN by the sanctioned handcraft seam (EPIC 1133 —
// the SKIN-lane preflight unblock).
//
// behavior_id: U1
// source_criterion: FR-001, adaptive_layouts
// description: The system shall present the adaptive login view with the declared platform slots (mobile, ios, android, macos).
//
// RED was certified against the inert stub this file replaced (cycle-log
// `Cycle: U1 (red)`, 2026-09-11; re-proved red this session before the
// green below landed): the paired test failed through the assertion
// `expect(result, isNot(isA<UnimplementedError>()))` on
// `UnimplementedError: subject_u1 not implemented`. The implementation
// presents the adaptive login view's declared platform slots — the Skin
// Contract's `adaptive_slots` declaration, in declared order — so the
// FR-001 surface the spec declares is the observable value the subject
// returns (the W1 hand-written seam renders the same declaration as the
// live view; U1 is its unit-side declaration surface).
//
// The subject name is derived from the behavior id (`subject_u1`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

/// Subject for behavior U1.
///
/// GREEN: the adaptive login view's declared platform slots, in the
/// Skin Contract's declared order.
List<String> subject_u1() => const <String>[
  'mobile',
  'ios',
  'android',
  'macos',
];
