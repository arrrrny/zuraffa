// Subject T8 (spec 1334, issue #1143): artifact pins — the typed ledger
// markdown/JSON shapes stay 0966-compatible, the verdict JSON records the
// per-screen kind report, and the summary/failure lines carry the #1143
// contract vocabulary.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

Object? subject_t8() {
  // --- the markdown table keeps the 0966 shape (no screen column) -------
  final ledger = TypedLedgerBuilder.derive(
    declared: [
      const DeclaredLedgerRow(
        surface: 'Sign In',
        kind: LedgerRowKind.presence,
        screen: '/login',
        declaredProvers: ['A1'],
      ),
      const DeclaredLedgerRow(
        surface: 'error banner',
        kind: LedgerRowKind.absence,
        screen: '/login',
        notRenderedIn: 'initial',
      ),
    ],
    greenBehaviors: const {'A1'},
  );
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

  // --- the typed JSON carries screen + advisory (the cache) -------------
  final json = TypedLedgerBuilder.toJson(ledger);
  final decoded = (jsonDecode(json) as List).cast<Map>();
  expect(decoded.first['screen'], '/login');
  expect(decoded.first['kind'], 'presence');
  expect(decoded.first['provenBy'], ['A1']);
  expect(decoded.first['state'], 'DONE');
  expect(decoded.last['kind'], 'absence');
  expect(decoded.last['state'], 'NOT-DONE');

  // --- the per-screen verdict JSON records the full report --------------
  final gamingLogin = TypedLedgerBuilder.derive(
    declared: [
      for (final literal in const ['Sign In', 'Email'])
        DeclaredLedgerRow(
          surface: literal,
          kind: LedgerRowKind.presence,
          screen: '/login',
          declaredProvers: ['A1'],
        ),
    ],
    greenBehaviors: const {'A1'},
  );
  final verdict = TypedCoverageGate.evaluateScreens(
    feature: '004-login-ui',
    ledgerByScreen: {'/login': gamingLogin},
  );
  final encoded = jsonDecode(verdict.encode()) as Map;
  expect(encoded['check'], 'typed-screens-coverage');
  expect(encoded['feature'], '004-login-ui');
  expect(encoded['legacy'], false);
  expect(encoded['passed'], false);
  final screens = encoded['screens'] as Map;
  expect(screens.keys, ['/login']);
  final loginScreen = screens['/login'] as Map;
  expect(loginScreen['status'], 'partially-traced');
  final kinds = loginScreen['kinds'] as List;
  expect(kinds, hasLength(5));
  final kindLabels = [for (final k in kinds.cast<Map>()) k['kind'] as String];
  expect(kindLabels, [
    'presence',
    'absence',
    'navigation',
    'state',
    'sequence',
  ]);
  final absenceKind = kinds.cast<Map>().singleWhere(
    (k) => k['kind'] == 'absence',
  );
  expect(absenceKind['traced'], 0);
  expect(absenceKind['total'], 0);
  expect(absenceKind['zeroTraced'], true);

  // --- the summary line vocabulary (the #1143 contract) -----------------
  final summary = verdict.summaryLine();
  expect(summary, contains('feature=004-login-ui'));
  expect(summary, contains('screens=1'));
  expect(summary, contains('legacy=false'));
  expect(summary, contains('outcome=gaps'));

  // --- the failure lines: screen + kind + fix hint -----------------------
  final failures = verdict.failureLines();
  expect(failures, hasLength(4)); // the four zero-traced kinds
  for (final line in failures) {
    expect(line, contains('/login'));
    expect(line, contains('zero traced rows'));
    expect(line, contains('--> fix:'));
    expect(line, contains('issue #1143'));
  }

  // --- legacy verdict JSON: the flag rides the feature-wide gate --------
  final legacyVerdict = TypedCoverageGate.evaluate(
    feature: 'legacy-app',
    rows: TypedLedgerBuilder.fromLedgerJson(
      jsonEncode([
        {
          'surface': 'Sign In',
          'kind': 'text',
          'provenBy': ['A1'],
          'state': 'DONE',
        },
      ]),
    ).rows,
    legacy: true,
  );
  final legacyEncoded = jsonDecode(legacyVerdict.encode()) as Map;
  expect(legacyEncoded['legacy'], true);
  expect(legacyEncoded['passed'], true);
  expect(legacyVerdict.summaryLine(), contains('legacy=true'));

  // --- the deck kind entries keep the 0966 label shape ------------------
  final deckEntries = XrayLedgerDeck.kindEntries(ledger);
  expect(
    deckEntries.map((e) => e.label).toList(),
    containsAll(['presence 1/1', 'absence 0/1']),
  );
  expect(
    deckEntries.singleWhere((e) => e.label == 'absence 0/1').state,
    'NOT-DONE',
  );

  return null;
}
