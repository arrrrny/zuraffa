// Subject T8 (spec 0966, issue #966, remediation pass 2): strength pins
// for the derived artifacts — markdown table shape, kind-coverage
// completeness polarity, partially-traced polarity, remaining verb
// branches, and the semantics if-chain guards.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

Object? subject_t8() {
  // --- remaining verb branches ----------------------------------------
  expect(
    LedgerRowKind.fromScenarioVerb('the error dialog does not render twice'),
    LedgerRowKind.absence,
  );
  expect(
    LedgerRowKind.fromScenarioVerb('no banner is shown while idle'),
    LedgerRowKind.absence,
  );
  expect(
    LedgerRowKind.fromScenarioVerb('the submit button is grayed out'),
    LedgerRowKind.state,
  );
  // ASCII arrow counts as a chain too (the → rule is an OR, not an AND).
  expect(
    LedgerRowKind.fromScenarioVerb('sign-in -> deal_list route hop'),
    LedgerRowKind.sequence,
  );

  // --- kind-coverage polarity: complete is FALSE for untraced kinds ----
  final ledger = TypedLedgerBuilder.derive(
    declared: const [
      DeclaredLedgerRow(
        surface: 'Sign In',
        kind: LedgerRowKind.presence,
        declaredProvers: ['A1'],
      ),
      DeclaredLedgerRow(
        surface: 'error banner',
        kind: LedgerRowKind.absence,
        notRenderedIn: 'initial',
      ),
    ],
    greenBehaviors: const {'A1'},
  );
  final coverage = TypedLedgerBuilder.kindCoverage(ledger);
  final presence = coverage.singleWhere(
    (c) => c.kind == LedgerRowKind.presence,
  );
  final absence = coverage.singleWhere((c) => c.kind == LedgerRowKind.absence);
  expect(presence.complete, isTrue);
  expect(absence.complete, isFalse); // 0/1 traced — NOT complete

  // --- partially-traced polarity: a fully-traced screen is not partial -
  expect(XrayLedgerOverlay.partiallyTraced(coverage), isTrue);
  final allTraced = TypedLedgerBuilder.derive(
    declared: const [
      DeclaredLedgerRow(
        surface: 'Sign In',
        kind: LedgerRowKind.presence,
        declaredProvers: ['A1'],
      ),
      DeclaredLedgerRow(
        surface: 'deal_list',
        kind: LedgerRowKind.navigation,
        declaredProvers: ['A4'],
      ),
    ],
    greenBehaviors: const {'A1', 'A4'},
  );
  expect(
    XrayLedgerOverlay.partiallyTraced(
      TypedLedgerBuilder.kindCoverage(allTraced),
    ),
    isFalse,
  );

  // --- markdown shape: the table header and a full row render verbatim -
  final markdown = TypedLedgerBuilder.toMarkdown(ledger);
  expect(
    markdown,
    contains('| surface | kind | proven by | state | semantics | advisory |'),
  );
  expect(markdown, contains('| --- | --- | --- | --- | --- | --- |'));
  expect(markdown, contains('| Sign In | presence | A1 | DONE |  |  |'));
  expect(
    markdown,
    contains(
      '| error banner | absence (not rendered in initial) |  | NOT-DONE | '
      'not rendered in initial |  |',
    ),
  );

  // --- semantics guards: a malformed row leaks no wrong semantics ------
  final malformed = TypedLedgerBuilder.toMarkdown([
    const TypedLedgerRow(
      surface: 'error banner',
      kind: LedgerRowKind.absence,
      state: 'NOT-DONE',
    ),
    const TypedLedgerRow(
      surface: 'affordances',
      kind: LedgerRowKind.state,
      state: 'NOT-DONE',
    ),
  ]);
  expect(malformed, isNot(contains('not rendered in null')));
  expect(malformed, isNot(contains('| null |')));
  // an unproven row renders no provers (empty proven-by cell).
  expect(malformed, contains('| error banner | absence |  | NOT-DONE |  |  |'));

  // --- advisory rows are not gate surface in the markdown counts -------
  final withGolden = TypedLedgerBuilder.toJson([
    const TypedLedgerRow(
      surface: 'login golden',
      kind: LedgerRowKind.golden,
      state: 'NOT-DONE',
      advisory: true,
      platformTolerance: {'ios': 0.5},
    ),
  ]);
  expect(withGolden, contains('"advisory":true'));
  expect(withGolden, contains('"platformTolerance":{"ios":0.5}'));

  return null;
}
