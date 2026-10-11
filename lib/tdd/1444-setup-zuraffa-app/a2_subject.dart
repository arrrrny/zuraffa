// GENERATED STUB — `zfa tdd gen A2` (spec 044-test-tdd-generation).
//
// behavior_id: A2
// source_criterion: AC-2
// description: no app shell is generated (pure Dart projects have no Flutter widgets)
//
// Honest-red stub (review of PR #1609): the previous body scaffolded its
// own temp project and then asserted that the main.dart it never wrote
// does not exist — a tautology that could never fail for a real
// regression. The behavior's real coverage lives in the paired test,
// which drives the production generation path directly
// (`AppShellBuilder.buildMain` in
// test/tdd/1444-setup-zuraffa-app/a2_test.dart); this subject stays
// unimplemented until the pure-Dart skip decision gets a synchronous seam
// a subject can drive. It is deliberately honest-red: it throws instead
// of pretending to verify.
//
// ignore_for_file: non_constant_identifier_names
library;

/// Scenario runner for behavior A2.
///
/// Throws [UnimplementedError] until the real implementation lands.
void subject_a2() => throw UnimplementedError('subject_a2 not implemented');
