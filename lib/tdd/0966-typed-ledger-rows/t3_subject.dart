// Subject T3 (spec 0966, issue #966): sequence rows — the interaction
// chain tap → loading → resolve is traced as a CHAIN end-to-end.
//
// A sequence row records the chain steps (the `When` clause the
// presence-only ledger discarded, FR-003). It is traced exactly when a
// green behavior traces the chain end-to-end AND the recorded chain is
// a chain (≥ 2 steps); a "sequence" with no recorded steps is malformed
// and never counts as proof — a single-pump presence assertion cannot
// satisfy it.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';

Object? subject_t3() {
  // --- plan time: the chain scenario yields a sequence row ------------
  final declared = <DeclaredLedgerRow>[
    DeclaredLedgerRow.fromScenario(
      surface: "Sign In",
      scenario: "shows the 'Sign In' title on the login view",
      declaredProvers: ['A1'],
    ),
    DeclaredLedgerRow.fromScenario(
      surface: 'sign-in submission',
      scenario: 'tap the submit button → loading → resolve → navigate',
      declaredProvers: ['A3'],
      steps: ['tap', 'loading', 'resolve', 'navigate'],
    ),
  ];
  final sequenceRow = declared.last;
  expect(sequenceRow.kind, LedgerRowKind.sequence);
  expect(sequenceRow.surface, 'sign-in submission');
  expect(sequenceRow.steps, ['tap', 'loading', 'resolve', 'navigate']);

  // --- traced chain end-to-end: green behavior + complete chain -------
  final honest = TypedLedgerBuilder.derive(
    declared: declared,
    greenBehaviors: const {'A1', 'A3'}, // A3 walks tap → loading → resolve
  );
  final traced = honest.singleWhere((r) => r.kind == LedgerRowKind.sequence);
  expect(traced.state, 'DONE');
  expect(traced.surface, 'sign-in submission');

  // the verdict + artifacts name the chain.
  final verdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: honest,
  );
  expect(verdict.feature, '004-login-ui');
  expect(verdict.passed, isTrue);
  expect(
    verdict.encode(),
    contains('"steps":["tap","loading","resolve","navigate"]'),
  );
  expect(
    TypedLedgerBuilder.toMarkdown(honest),
    contains('tap → loading → resolve → navigate'),
  );

  // --- an incomplete chain never counts as proof ----------------------
  // A green behavior over a "sequence" with no recorded steps traced
  // nothing: the When clause is discarded again. The row stays
  // NOT-DONE and the kind stays a gap (FR-003).
  final malformed = TypedLedgerBuilder.derive(
    declared: const [
      DeclaredLedgerRow(
        surface: 'sign-in submission',
        kind: LedgerRowKind.sequence,
        declaredProvers: ['A3'],
      ),
    ],
    greenBehaviors: const {'A3'},
  );
  final malformedRow = malformed.single;
  expect(malformedRow.state, 'NOT-DONE');
  expect(malformedRow.surface, 'sign-in submission');
  final malformedVerdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: malformed,
  );
  expect(malformedVerdict.feature, '004-login-ui');
  expect(malformedVerdict.passed, isFalse);
  expect(
    malformedVerdict.untracedKinds.map((c) => c.kind.label),
    contains('sequence'),
  );

  // --- the gaming view's single-pump presence assertion cannot --------
  // satisfy the chain either: planned-but-green presence is not a
  // sequence prover (the plan assigns A3 only to the chain scenario).
  final gaming = TypedLedgerBuilder.derive(
    declared: declared,
    greenBehaviors: const {'A1'},
  );
  final gamingSequence = gaming.singleWhere(
    (r) => r.kind == LedgerRowKind.sequence,
  );
  expect(gamingSequence.state, 'NOT-DONE');
  expect(gamingSequence.steps, ['tap', 'loading', 'resolve', 'navigate']);

  return null;
}
