// Subject T1 (spec 1334, issue #1143): the five-kind vocabulary + golden as
// an advisory presence row.
//
// AC-1/AC-5: every ledger row carries one of EXACTLY five kinds — presence,
// absence, navigation, state, sequence — there is no sixth "golden" kind.
// A golden (visual regression) row carries kind presence, an advisory:true
// flag, and per-platform tolerance; it never blocks the merge gate
// (flaky economics on Intel CI — recorded decision) and the deck reports
// it ADVISORY.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

Object? subject_t1() {
  // --- five kinds, exactly (AC-1) --------------------------------------
  expect(LedgerRowKind.values, hasLength(5));
  expect(LedgerRowKind.values.map((k) => k.label).toList(), [
    'presence',
    'absence',
    'navigation',
    'state',
    'sequence',
  ]);
  // no golden value exists in the vocabulary.
  expect(
    LedgerRowKind.values.map((k) => k.name).toList(),
    isNot(contains('golden')),
  );

  // --- a golden scenario yields an ADVISORY presence row (AC-5) --------
  expect(
    LedgerRowKind.fromScenarioVerb(
      'the login view matches the golden snapshot on every platform',
    ),
    LedgerRowKind.presence, // presence — never a sixth kind
  );
  expect(
    LedgerRowKind.isGoldenScenario(
      'the login view matches the golden snapshot on every platform',
    ),
    isTrue,
  );
  expect(LedgerRowKind.isGoldenScenario("shows the 'Sign In' title"), isFalse);

  final golden = DeclaredLedgerRow.fromScenario(
    surface: 'login view matches the golden',
    scenario: 'the login view matches the golden snapshot on every platform',
    platformTolerance: {'ios': 0.5, 'android': 1.0, 'web': 2.0},
  );
  expect(golden.kind, LedgerRowKind.presence);
  expect(golden.advisory, isTrue); // the flag, not the kind
  expect(golden.platformTolerance['android'], 1.0);

  // --- derive + gate: goldens never block (AC-5) -----------------------
  final ledger = TypedLedgerBuilder.derive(
    declared: [
      DeclaredLedgerRow.fromScenario(
        surface: "Sign In",
        scenario: "shows the 'Sign In' title on the login view",
        declaredProvers: ['A1'],
      ),
      DeclaredLedgerRow.fromScenario(
        surface: 'deal_list',
        scenario: 'the app navigates to the route "deal_list" after sign-in',
        declaredProvers: ['A4'],
      ),
      golden, // unproven — and irrelevant to the outcome
    ],
    greenBehaviors: const {'A1', 'A4'},
  );
  final goldenRow = ledger.singleWhere((r) => r.advisory);
  expect(goldenRow.kind, LedgerRowKind.presence);
  expect(goldenRow.state, 'NOT-DONE'); // red goldens are visible...
  final verdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: ledger,
  );
  expect(verdict.passed, isTrue); // ...but never block the gate
  expect(verdict.advisoryRows, hasLength(1));
  expect(verdict.encode(), contains('"platformTolerance":{"ios":0.5,'));
  expect(verdict.summaryLine(), contains('advisory=1'));

  // the advisory golden row is NOT gate surface: it does not inflate the
  // presence kind totals (kind coverage counts gate rows only).
  final presenceCoverage = verdict.kindCoverage.singleWhere(
    (c) => c.kind == LedgerRowKind.presence,
  );
  expect(presenceCoverage.total, 1); // "Sign In" only — not the golden

  // --- the deck reports goldens separately as ADVISORY -----------------
  final advisoryEntries = XrayLedgerDeck.advisoryEntries(ledger);
  expect(advisoryEntries, hasLength(1));
  expect(advisoryEntries.single.label, contains('golden'));
  expect(advisoryEntries.single.label, contains('android: ±1.0px'));
  expect(advisoryEntries.single.state, 'ADVISORY');

  return null;
}
