// Subject T7 (spec 0966, issue #966, remediation pass): the FULL
// plan-time verb→kind matrix (FR-005) — every branch of the classifier
// is pinned, and the precedence rules hold (sequence > navigation >
// absence > state > presence).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';

Object? subject_t7() {
  // --- presence: the default render verbs ------------------------------
  expect(
    LedgerRowKind.fromScenarioVerb("shows the 'Sign In' title"),
    LedgerRowKind.presence,
  );
  expect(
    LedgerRowKind.fromScenarioVerb('renders the deal row'),
    LedgerRowKind.presence,
  );
  expect(
    LedgerRowKind.fromScenarioVerb('displays the total price'),
    LedgerRowKind.presence,
  );

  // --- absence: every absence verb branch ------------------------------
  for (final scenario in [
    'the error banner is hidden until a failure occurs',
    "the 'Saving…' indicator is not shown when idle",
    'the spinner is not rendered in the loaded state',
    'the error dialog does not appear on success',
    'the retry button is absent in the initial state',
    'the loading row disappears when the deals resolve',
  ]) {
    expect(
      LedgerRowKind.fromScenarioVerb(scenario),
      LedgerRowKind.absence,
      reason: scenario,
    );
  }

  // --- navigation: every navigation verb branch ------------------------
  for (final scenario in [
    'the app navigates to the route "deal_list"',
    'the app routes to the deal list view',
    'the user lands on the deal_list page',
    'the flow pushes the deal_list route',
    'sign-in goes to the deal list',
  ]) {
    expect(
      LedgerRowKind.fromScenarioVerb(scenario),
      LedgerRowKind.navigation,
      reason: scenario,
    );
  }

  // --- state: every attribute verb branch (no chain in sight) ----------
  for (final scenario in [
    'the submit button is disabled while the submission is in flight',
    'the save button is enabled once the form is valid',
    'the coupon field is readonly for locked deals',
    'the deal row is selected after the tap target releases',
    'the search field is focused on view entry',
    'the details panel is expanded for the pinned deal',
  ]) {
    expect(
      LedgerRowKind.fromScenarioVerb(scenario),
      LedgerRowKind.state,
      reason: scenario,
    );
  }

  // --- sequence: every chain shape (arrow and prose) -------------------
  for (final scenario in [
    'tap the submit button → loading → resolve → navigate',
    'tap the submit button and the loading indicator appears',
    'tap the row then the deals resolve',
    'tap checkout and the app navigates to the confirmation',
    'while loading the deals then the view resolves',
  ]) {
    expect(
      LedgerRowKind.fromScenarioVerb(scenario),
      LedgerRowKind.sequence,
      reason: scenario,
    );
  }

  // --- golden: advisory snapshot scenarios -----------------------------
  expect(
    LedgerRowKind.fromScenarioVerb('the login view matches the golden'),
    LedgerRowKind.golden,
  );
  expect(
    LedgerRowKind.fromScenarioVerb('the deal card passes the snapshot check'),
    LedgerRowKind.golden,
  );

  // --- precedence: the richest kind wins -------------------------------
  // a chain containing a navigation verb is a SEQUENCE.
  expect(
    LedgerRowKind.fromScenarioVerb(
      'tap sign in → loading → navigates to deal_list',
    ),
    LedgerRowKind.sequence,
  );
  // a navigation scenario that also shows something is NAVIGATION.
  expect(
    LedgerRowKind.fromScenarioVerb(
      'navigates to deal_list and shows the deals',
    ),
    LedgerRowKind.navigation,
  );
  // an attribute verb without a chain is STATE, not sequence.
  expect(
    LedgerRowKind.fromScenarioVerb('the buttons are disabled while in flight'),
    LedgerRowKind.state,
  );
  // a hidden verb beats a presence reading.
  expect(
    LedgerRowKind.fromScenarioVerb(
      "shows no banner — it stays hidden while idle",
    ),
    LedgerRowKind.absence,
  );

  // --- plan-time assignment composes: fromScenario builds typed rows ---
  final row = DeclaredLedgerRow.fromScenario(
    surface: 'deal_list',
    scenario: 'the flow pushes the deal_list route',
    declaredProvers: const ['A4'],
  );
  expect(row.kind, LedgerRowKind.navigation);
  expect(row.advisory, isFalse);

  return null;
}
