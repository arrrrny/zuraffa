// Subject T2 (spec 0966, issue #966): absence assertions in the ledger —
// the error banner hidden initially is TRACED when hidden.
//
// An absence row expresses "not rendered in state S" (FR-002). It is
// traced exactly when a green behavior asserts the surface hidden in
// that state; an absence assertion that never names the state it pins
// is malformed and never counts as proof (honest-red discipline).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';

Object? subject_t2() {
  // --- honest ledger: the error banner hidden initially is traced -----
  final declared = <DeclaredLedgerRow>[
    DeclaredLedgerRow.fromScenario(
      surface: "Sign In",
      scenario: "shows the 'Sign In' title on the login view",
      declaredProvers: ['A1'],
    ),
    const DeclaredLedgerRow(
      surface: 'error banner',
      kind: LedgerRowKind.absence,
      declaredProvers: ['A2'],
      notRenderedIn: 'initial',
    ),
  ];
  final honest = TypedLedgerBuilder.derive(
    declared: declared,
    greenBehaviors: const {'A1', 'A2'}, // A2: banner hidden in initial
  );

  // the absence row is TRACED when hidden: green prover + declared state.
  final absenceRow = honest.singleWhere((r) => r.kind == LedgerRowKind.absence);
  expect(absenceRow.state, 'DONE');
  expect(absenceRow.surface, 'error banner');
  expect(absenceRow.notRenderedIn, 'initial');

  // the verdict carries the state and the absence kind is traced.
  final verdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: honest,
  );
  expect(verdict.feature, '004-login-ui');
  expect(verdict.passed, isTrue);
  final absenceCoverage = verdict.kindCoverage.singleWhere(
    (c) => c.kind == LedgerRowKind.absence,
  );
  expect(absenceCoverage.untraced, isFalse);
  expect(absenceCoverage.complete, isTrue);

  // the artifacts record the absence semantics ("not rendered in S").
  final json = TypedLedgerBuilder.toJson(honest);
  expect(json, contains('"notRenderedIn":"initial"'));
  final markdown = TypedLedgerBuilder.toMarkdown(honest);
  expect(markdown, contains('not rendered in initial'));

  // --- a permanently-rendered banner cannot satisfy the absence row ---
  // The gaming view renders the banner always; its "prover" (the
  // presence behavior A1) is not a hiddenness assertion, so the absence
  // row keeps NO prover and stays a gap.
  final gaming = TypedLedgerBuilder.derive(
    declared: declared,
    greenBehaviors: const {'A1'},
  );
  final gamingAbsence = gaming.singleWhere(
    (r) => r.kind == LedgerRowKind.absence,
  );
  expect(gamingAbsence.state, 'NOT-DONE');
  final gamingVerdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: gaming,
  );
  expect(gamingVerdict.feature, '004-login-ui');
  expect(gamingVerdict.passed, isFalse);
  expect(
    gamingVerdict.untracedKinds.map((c) => c.kind.label),
    contains('absence'),
  );

  // --- a malformed absence assertion never counts as proof ------------
  // An absence row that never names the state it pins ("hidden") is not
  // an absence assertion: it stays NOT-DONE even with a green prover,
  // and the gap names the missing state (FR-002).
  final malformed = TypedLedgerBuilder.derive(
    declared: const [
      DeclaredLedgerRow(
        surface: 'error banner',
        kind: LedgerRowKind.absence,
        declaredProvers: ['A2'],
      ),
    ],
    greenBehaviors: const {'A2'},
  );
  final malformedRow = malformed.single;
  expect(malformedRow.state, 'NOT-DONE');
  expect(malformedRow.surface, 'error banner');
  final malformedVerdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: malformed,
  );
  expect(malformedVerdict.passed, isFalse);
  expect(malformedVerdict.rowGaps.join(' '), contains('absence'));

  return null;
}
