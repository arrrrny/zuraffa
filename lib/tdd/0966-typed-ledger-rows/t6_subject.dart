// Subject T6 (spec 0966, issue #966): goldens stay advisory, navigation
// is a kind of its own.
//
// FR-005: the navigation verb yields a NAVIGATION row (the route
// outcome sign-in → deal_list). FR-007 + AC-11: golden rows are
// advisory with per-platform tolerance — they never block the merge
// gate regardless of state (recorded decision: flaky economics on slow
// CI) and the deck reports them separately as advisory.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

Object? subject_t6() {
  // --- the navigation verb yields a NAVIGATION row (FR-005, AC-6) -----
  final nav = DeclaredLedgerRow.fromScenario(
    surface: 'deal_list',
    scenario: 'the app navigates to the route "deal_list" after sign-in',
    declaredProvers: ['A4'],
  );
  expect(nav.kind, LedgerRowKind.navigation);
  expect(nav.surface, 'deal_list');

  // --- the golden scenario yields an ADVISORY golden row --------------
  final golden = DeclaredLedgerRow.fromScenario(
    surface: 'login view matches the golden',
    scenario: 'the login view matches the golden snapshot on every platform',
    platformTolerance: {'ios': 0.5, 'android': 1.0, 'web': 2.0},
  );
  expect(golden.kind, LedgerRowKind.golden);
  expect(golden.surface, 'login view matches the golden');
  expect(golden.advisory, isTrue); // advisory by kind, never gate surface
  expect(golden.platformTolerance['android'], 1.0);

  // --- the gate: goldens NEVER block the merge gate (AC-11) -----------
  // Every gate row traces; the golden row has NO green prover at all —
  // and the verdict still passes, reporting the golden as advisory.
  final ledger = TypedLedgerBuilder.derive(
    declared: [
      DeclaredLedgerRow.fromScenario(
        surface: "Sign In",
        scenario: "shows the 'Sign In' title on the login view",
        declaredProvers: ['A1'],
      ),
      nav,
      golden, // unproven — and irrelevant to the outcome
    ],
    greenBehaviors: const {'A1', 'A4'},
  );
  final goldenRow = ledger.singleWhere((r) => r.kind == LedgerRowKind.golden);
  expect(goldenRow.state, 'NOT-DONE'); // red goldens are visible...
  final verdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: ledger,
  );
  expect(verdict.feature, '004-login-ui');
  expect(verdict.passed, isTrue); // ...but never block the gate
  expect(verdict.advisoryRows, hasLength(1));
  expect(verdict.encode(), contains('"platformTolerance":{"ios":0.5,'));

  // kind coverage excludes advisory rows (they are not gate surface).
  expect(
    verdict.kindCoverage.every((c) => c.kind != LedgerRowKind.golden),
    isTrue,
  );

  // --- the deck reports goldens separately as advisory (FR-007) -------
  final advisoryEntries = XrayLedgerDeck.advisoryEntries(ledger);
  expect(advisoryEntries, hasLength(1));
  expect(advisoryEntries.single.label, contains('golden'));
  expect(advisoryEntries.single.label, contains('android: ±1.0px'));
  expect(advisoryEntries.single.state, 'ADVISORY');

  return null;
}
