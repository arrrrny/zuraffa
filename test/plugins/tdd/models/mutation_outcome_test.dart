// Tests for the MutationOutcome model (spec 044-test-tdd-generation, T003/T004).
//
// `MutationOutcome` is the per-mutant classification. `MutationGateDecision`
// is the per-audit gate decision reported to CI. The two enums together
// implement FR-014 (three separate buckets) and FR-017/019 (five gate
// decisions, strict policy).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/mutation_outcome.dart';

void main() {
  group('MutationOutcome', () {
    test('has exactly four values (FR-014, FR-016)', () {
      expect(MutationOutcome.values, hasLength(4));
      expect(
        MutationOutcome.values.toSet(),
        equals({
          MutationOutcome.killed,
          MutationOutcome.survived,
          MutationOutcome.timedOut,
          MutationOutcome.notAssessed,
        }),
      );
    });

    test('killed, survived, timedOut are mutually exclusive (FR-014)', () {
      expect(MutationOutcome.killed != MutationOutcome.survived, isTrue);
      expect(MutationOutcome.survived != MutationOutcome.timedOut, isTrue);
      expect(MutationOutcome.timedOut != MutationOutcome.killed, isTrue);
    });

    test('notAssessed is distinct from killed/survived/timedOut (FR-016)', () {
      expect(MutationOutcome.notAssessed != MutationOutcome.killed, isTrue);
      expect(MutationOutcome.notAssessed != MutationOutcome.survived, isTrue);
      expect(MutationOutcome.notAssessed != MutationOutcome.timedOut, isTrue);
    });
  });

  group('MutationGateDecision', () {
    test('has exactly five values (FR-017, FR-019)', () {
      expect(MutationGateDecision.values, hasLength(5));
      expect(
        MutationGateDecision.values.toSet(),
        equals({
          MutationGateDecision.pass,
          MutationGateDecision.failSurvived,
          MutationGateDecision.failTimeout,
          MutationGateDecision.preflightRed,
          MutationGateDecision.notAssessed,
        }),
      );
    });

    test('decide: survived takes precedence over timeout (FR-017)', () {
      // Strict policy: ANY survived OR timed-out fails the gate.
      // When both survived and timed-out are present, the gate is
      // FAIL_SURVIVED (survived is the more actionable bucket — the
      // test failed to catch a real mutant).
      final decision = MutationGateDecision.decide(
        killedCount: 5,
        survivedCount: 1,
        timedOutCount: 2,
        notAssessed: false,
        preflightRed: false,
      );
      expect(decision, MutationGateDecision.failSurvived);
    });

    test('decide: timeout-only → FAIL_TIMEOUT (FR-017)', () {
      final decision = MutationGateDecision.decide(
        killedCount: 5,
        survivedCount: 0,
        timedOutCount: 1,
        notAssessed: false,
        preflightRed: false,
      );
      expect(decision, MutationGateDecision.failTimeout);
    });

    test('decide: all killed, no survivors, no timeouts → PASS', () {
      final decision = MutationGateDecision.decide(
        killedCount: 10,
        survivedCount: 0,
        timedOutCount: 0,
        notAssessed: false,
        preflightRed: false,
      );
      expect(decision, MutationGateDecision.pass);
    });

    test('decide: preflight red wins over everything (FR-013)', () {
      final decision = MutationGateDecision.decide(
        killedCount: 100,
        survivedCount: 0,
        timedOutCount: 0,
        notAssessed: false,
        preflightRed: true,
      );
      expect(decision, MutationGateDecision.preflightRed);
    });

    test('decide: notAssessed wins over preflight (FR-016)', () {
      // If the mutation tool is unavailable or the report is unparseable,
      // the gate is NOT_ASSESSED even if the preflight was red — the
      // audit never reached a state where the gate could be said to
      // pass or fail.
      final decision = MutationGateDecision.decide(
        killedCount: 0,
        survivedCount: 0,
        timedOutCount: 0,
        notAssessed: true,
        preflightRed: true,
      );
      expect(decision, MutationGateDecision.notAssessed);
    });

    test('gate label is stable lowercase snake_case (FR-019)', () {
      expect(MutationGateDecision.pass.label, 'pass');
      expect(MutationGateDecision.failSurvived.label, 'fail_survived');
      expect(MutationGateDecision.failTimeout.label, 'fail_timeout');
      expect(MutationGateDecision.preflightRed.label, 'preflight_red');
      expect(MutationGateDecision.notAssessed.label, 'not_assessed');
    });
  });
}
