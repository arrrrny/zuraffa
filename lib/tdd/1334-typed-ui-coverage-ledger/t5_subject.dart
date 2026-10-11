// Subject T5 (spec 1334, issue #1143): plan-time kind assignment — the
// ledger consumes the finder-kind taxonomy's assignments verbatim.
//
// AC-4: kinds are derived from the spec's scenarios at plan time (presence
// scenarios → presence, state transitions → state, navigation outcomes →
// navigation, absence → absence, chains → sequence); the ledger never
// re-infers a kind post hoc — a row whose kind the plan assigned
// explicitly survives derivation verbatim.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';

Object? subject_t5() {
  // --- the verb→kind matrix at plan time (AC-4, #964 composition) -------
  final matrix = <String, LedgerRowKind>{
    "shows the 'Sign In' title on the login view": LedgerRowKind.presence,
    'the error banner is hidden until a failure occurs': LedgerRowKind.absence,
    'the app navigates to the route "deal_list" after sign-in':
        LedgerRowKind.navigation,
    'the affordances are disabled while the submission is in flight':
        LedgerRowKind.state,
    'tap the submit button → loading → resolve → navigate':
        LedgerRowKind.sequence,
  };
  for (final entry in matrix.entries) {
    expect(
      LedgerRowKind.fromScenarioVerb(entry.key),
      entry.value,
      reason: entry.key,
    );
  }

  // fromScenario derives rows whose kinds the verbs assigned.
  for (final entry in matrix.entries) {
    final row = DeclaredLedgerRow.fromScenario(
      surface: 'surface of: ${entry.key}',
      scenario: entry.key,
      declaredProvers: ['A1'],
    );
    expect(row.kind, entry.value, reason: entry.key);
    expect(row.advisory, isFalse, reason: entry.key); // not golden-flavored
  }

  // --- the ledger consumes plan-time assignments VERBATIM (AC-4) --------
  // A row whose kind the plan assigned explicitly (not from verbs) keeps
  // exactly that kind — the ledger does not re-infer or relabel.
  final declared = [
    const DeclaredLedgerRow(
      surface: 'kiosk lockout banner',
      kind: LedgerRowKind.absence, // plan-assigned, verb-free surface name
      screen: '/login',
      declaredProvers: ['A9'],
      notRenderedIn: 'kiosk',
    ),
    const DeclaredLedgerRow(
      surface: 'settings deep link',
      kind: LedgerRowKind.navigation, // plan-assigned
      screen: '/login',
      declaredProvers: ['A10'],
    ),
  ];
  final derived = TypedLedgerBuilder.derive(
    declared: declared,
    greenBehaviors: const {'A9', 'A10'},
  );
  expect(derived[0].kind, LedgerRowKind.absence); // verbatim
  expect(derived[1].kind, LedgerRowKind.navigation); // verbatim

  // the screen assignment rides the row through derivation.
  expect(derived.every((r) => r.screen == '/login'), isTrue);
  final byScreen = TypedLedgerBuilder.groupByScreen(derived);
  expect(byScreen['/login'], hasLength(2));

  // --- golden scenarios: kind presence + advisory (composed) -------------
  final goldenRow = DeclaredLedgerRow.fromScenario(
    surface: 'login view matches the golden',
    scenario: 'the login view matches the golden snapshot on every platform',
    platformTolerance: {'ios': 0.5},
  );
  expect(goldenRow.kind, LedgerRowKind.presence); // plan-time verb default
  expect(goldenRow.advisory, isTrue); // ...flagged advisory at plan time

  return null;
}
