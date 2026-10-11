// SPEC 1420 — the vacuous-green stop's declared-trace remedy vocabulary.
//
// Issue #1420: the marker-absent vacuous-green stop claimed the behavior was
// "fallback-routed (no traces: to a declared contract row)" — FALSE when the
// traces cell resolves a declared Key Entity row, and the prescribed
// `add traces: <ContractRow>` remedy impossible (entity rows declare no
// methods). The remedy becomes a single-sourced wording function:
// re-gen from the declared trace (the #1388 stale-artifact class) or the hand
// step — never the "add traces" advice.
//
// Test map (fast tier — the wording source):
//   U-1420-V1 — the wording names re-gen + the hand step and never the
//               "add traces"/"no traces" vocabulary.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

void main() {
  test('U-1420-V1: the declared-trace remedy names re-gen + the hand step, '
      'never the false "add traces"/"no traces" advice', () {
    final remedy = vacuousGuardDeclaredTraceRemedyFor(
      behaviorId: 'U1',
      testPath: 'test/tdd/1420/u1_test.dart',
    );

    // The working paths, named.
    expect(remedy, contains('zfa tdd gen U1'));
    expect(remedy, contains('test/tdd/1420/u1_test.dart'));
    expect(remedy, contains('re-run make'));
    // The false and impossible vocabulary is gone.
    expect(remedy, isNot(contains('add traces')));
    expect(remedy, isNot(contains('no traces')));
  });
}
