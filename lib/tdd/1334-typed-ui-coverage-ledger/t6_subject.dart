// Subject T6 (spec 1334, issue #1143): legacy mode — ledgers without kind
// fields are treated as presence-only; the gate does not break existing
// projects.
//
// AC-6: a 075-shaped ledger JSON (kind labels text/route/affordance/key, no
// typed kind field) reads as presence rows + legacy mode; the gate is
// rows-only (all-green passes, one-red fails on the row gap only — no kind
// gaps, no per-screen tightening). A 0966-written ledger with "golden"
// rows reads as TYPED (reclassified presence + advisory).
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';

Object? subject_t6() {
  // --- a 075-shaped ledger (produced by the legacy builder itself) -------
  final legacyJson = jsonEncode([
    {
      'surface': 'Sign In',
      'kind': 'text',
      'provenBy': ['A1'],
      'state': 'DONE',
    },
    {
      'surface': 'deal_list',
      'kind': 'route',
      'provenBy': ['A4'],
      'state': 'DONE',
    },
    {
      'surface': 'submit form',
      'kind': 'affordance',
      'provenBy': [],
      'state': 'NOT-DONE',
    },
    {
      'surface': 't.app.name',
      'kind': 'key',
      'provenBy': [],
      'state': 'NOT-DONE',
    },
  ]);

  // --- kindless rows are reclassified presence; the parse is legacy ------
  final parsed = TypedLedgerBuilder.fromLedgerJson(legacyJson);
  expect(parsed.legacy, isTrue); // NO row carried a typed kind label
  expect(parsed.rows, hasLength(4));
  // every row is a presence row now (AC-1: reclassification).
  expect(parsed.rows.map((r) => r.kind).toSet(), {LedgerRowKind.presence});
  expect(parsed.rows.map((r) => r.surface), [
    'Sign In',
    'deal_list',
    'submit form',
    't.app.name',
  ]);
  // state is recomputed at read time from the recorded provers.
  expect(parsed.rows[0].state, 'DONE');
  expect(parsed.rows[2].state, 'NOT-DONE');

  // --- the legacy gate: rows only (AC-6) -----------------------------------
  // all-green legacy passes with ZERO kind gaps (no tightening).
  final allGreenJson = jsonEncode([
    {
      'surface': 'Sign In',
      'kind': 'text',
      'provenBy': ['A1'],
      'state': 'DONE',
    },
    {
      'surface': 'deal_list',
      'kind': 'route',
      'provenBy': ['A4'],
      'state': 'DONE',
    },
  ]);
  final allGreen = TypedLedgerBuilder.fromLedgerJson(allGreenJson);
  expect(allGreen.legacy, isTrue);
  final legacyVerdict = TypedCoverageGate.evaluate(
    feature: 'legacy-app',
    rows: allGreen.rows,
    legacy: allGreen.legacy,
  );
  expect(legacyVerdict.legacy, isTrue);
  expect(legacyVerdict.passed, isTrue); // existing projects keep passing
  expect(legacyVerdict.untracedKinds, isEmpty);
  expect(legacyVerdict.encode(), contains('"legacy":true'));

  // one-red legacy fails on the ROW gap only — never on kind gaps.
  final oneRed = TypedLedgerBuilder.fromLedgerJson(legacyJson);
  final redVerdict = TypedCoverageGate.evaluate(
    feature: 'legacy-app',
    rows: oneRed.rows,
    legacy: oneRed.legacy,
  );
  expect(redVerdict.passed, isFalse); // row gaps still count (presence-only)
  expect(redVerdict.unproven, 2);
  expect(redVerdict.untracedKinds, isEmpty); // but no KIND gaps
  expect(redVerdict.failureLines().join('\n'), contains('submit form'));

  // --- the per-screen gate skips kind tightening for legacy --------------
  // A legacy ledger grouped under its screen ('' — kindless rows carry no
  // screen) evaluates rows-only: the all-green ledger passes even though
  // four of five kinds have zero rows (AC-6 — no per-screen tightening).
  final legacyScreens = TypedCoverageGate.evaluateScreens(
    feature: 'legacy-app',
    ledgerByScreen: TypedLedgerBuilder.groupByScreen(allGreen.rows),
    legacy: allGreen.legacy,
  );
  expect(legacyScreens.legacy, isTrue);
  expect(legacyScreens.passed, isTrue); // kind gaps NOT counted in legacy
  expect(legacyScreens.summaryLine(), contains('legacy=true'));

  // the same shape as TYPED rows WOULD fail — the tightening is real.
  final typedSameShape = TypedCoverageGate.evaluateScreens(
    feature: 'legacy-app',
    ledgerByScreen: TypedLedgerBuilder.groupByScreen(allGreen.rows),
    legacy: false, // same rows, evaluated as typed
  );
  expect(typedSameShape.passed, isFalse); // four zero-traced kind gaps now
  expect(typedSameShape.legacy, isFalse);

  // --- a 0966-written ledger with golden rows reads as TYPED -------------
  final goldenLedgerJson = jsonEncode([
    {
      'surface': 'Sign In',
      'kind': 'presence',
      'provenBy': ['A1'],
      'state': 'DONE',
    },
    {
      'surface': 'login view matches the golden',
      'kind': 'golden', // the 0966 sixth-kind label
      'provenBy': [],
      'state': 'NOT-DONE',
      'advisory': true,
      'platformTolerance': {'ios': 0.5, 'android': 1.0},
    },
  ]);
  final goldenParsed = TypedLedgerBuilder.fromLedgerJson(goldenLedgerJson);
  expect(goldenParsed.legacy, isFalse); // typed — presence + golden labels
  final goldenRow = goldenParsed.rows.singleWhere((r) => r.advisory);
  expect(goldenRow.kind, LedgerRowKind.presence); // reclassified
  expect(goldenRow.platformTolerance['android'], 1.0);
  expect(goldenParsed.rows.first.kind, LedgerRowKind.presence);
  expect(goldenParsed.rows.first.state, 'DONE');

  // The `golden` label ALONE (a golden-only 0966 artifact, no other typed
  // row, no advisory field) still classifies the ledger TYPED and forces
  // the row advisory — the label is itself a typed signal, not legacy.
  final goldenOnlyJson = jsonEncode([
    {
      'surface': 'login view matches the golden',
      'kind': 'golden',
      'provenBy': [],
      'state': 'NOT-DONE',
      'platformTolerance': {'ios': 0.5},
    },
  ]);
  final goldenOnly = TypedLedgerBuilder.fromLedgerJson(goldenOnlyJson);
  expect(goldenOnly.legacy, isFalse); // the golden label counts as typed
  expect(goldenOnly.rows.single.kind, LedgerRowKind.presence);
  expect(goldenOnly.rows.single.advisory, isTrue); // forced, field or not
  expect(goldenOnly.rows.single.platformTolerance['ios'], 0.5);

  // --- a missing kind field is legacy; an unknown label is legacy --------
  final noKindJson = jsonEncode([
    {
      'surface': 'Sign In',
      'provenBy': ['A1'],
      'state': 'DONE',
    },
  ]);
  expect(TypedLedgerBuilder.fromLedgerJson(noKindJson).legacy, isTrue);
  final unknownJson = jsonEncode([
    {'surface': 'Sign In', 'kind': 'vibes', 'provenBy': [], 'state': 'DONE'},
  ]);
  final unknownParsed = TypedLedgerBuilder.fromLedgerJson(unknownJson);
  expect(unknownParsed.legacy, isTrue);
  expect(unknownParsed.rows.single.kind, LedgerRowKind.presence);

  // --- dirty field types degrade, never throw (AC-6 tolerance seam) ------
  // A stored ledger is old/foreign input: a string "advisory" flag, a
  // numeric screen, a non-string kind/surface must reclassify to the
  // presence fallback instead of crashing the read with a cast error.
  final dirtyJson = jsonEncode([
    {
      'surface': 42,
      'kind': 7,
      'screen': 3,
      'advisory': 'true',
      'provenBy': ['A1'],
      'state': 'DONE',
    },
  ]);
  final dirtyParsed = TypedLedgerBuilder.fromLedgerJson(dirtyJson);
  expect(dirtyParsed.rows, hasLength(1));
  expect(dirtyParsed.rows.single.kind, LedgerRowKind.presence);
  expect(dirtyParsed.rows.single.surface, '');
  expect(dirtyParsed.rows.single.screen, '');
  expect(dirtyParsed.rows.single.advisory, isFalse); // 'true' is not true

  // --- a verdict-shaped JSON (the 075 gate encode) also reads -----------
  final verdictJson = jsonEncode({
    'check': 'ui-coverage',
    'feature': 'legacy-app',
    'surfaces': [
      {
        'surface': 'Sign In',
        'kind': 'text',
        'provenBy': ['A1'],
        'state': 'DONE',
      },
    ],
    'passed': true,
  });
  final fromVerdict = TypedLedgerBuilder.fromLedgerJson(verdictJson);
  expect(fromVerdict.legacy, isTrue);
  expect(fromVerdict.rows, hasLength(1));
  expect(fromVerdict.rows.single.state, 'DONE');

  // --- the legacy 075 builder output round-trips directly ---------------
  final uiRows = <UiSurfaceRow>[
    const UiSurfaceRow(
      surface: 'Sign In',
      kind: UiSurfaceKind.text,
      provers: ['A1'],
      state: 'DONE',
    ),
  ];
  final roundTripped = TypedLedgerBuilder.fromLedgerJson(
    UiLedgerBuilder.toJson(uiRows),
  );
  expect(roundTripped.legacy, isTrue);
  expect(roundTripped.rows.single.kind, LedgerRowKind.presence);
  expect(roundTripped.rows.single.state, 'DONE');

  return null;
}
