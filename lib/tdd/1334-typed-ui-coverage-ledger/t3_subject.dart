// Subject T3 (spec 1334, issue #1143): the per-screen gate — untraced
// kinds count as gaps, named per screen, with fix hints.
//
// AC-2: the gaming `/login` (presence-only) FAILS naming the four
// zero-traced kinds; the honest five-kind screen passes; a fully-traced
// screen next to a gaming one is distinguishable.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';

Object? subject_t3() {
  // --- fixtures -----------------------------------------------------------
  final gamingLogin = TypedLedgerBuilder.derive(
    declared: [
      for (final literal in const ['Sign In', 'Email', 'Password'])
        DeclaredLedgerRow(
          surface: literal,
          kind: LedgerRowKind.presence,
          screen: '/login',
          declaredProvers: ['A1'],
        ),
    ],
    greenBehaviors: const {'A1'},
  );

  final honestLogin = TypedLedgerBuilder.derive(
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
        declaredProvers: ['A2'],
        notRenderedIn: 'initial',
      ),
      const DeclaredLedgerRow(
        surface: 'deal_list',
        kind: LedgerRowKind.navigation,
        screen: '/login',
        declaredProvers: ['A4'],
      ),
      const DeclaredLedgerRow(
        surface: 'submit affordance',
        kind: LedgerRowKind.state,
        screen: '/login',
        declaredProvers: ['A5'],
        attribute: 'onPressed = null @ in-flight',
      ),
      const DeclaredLedgerRow(
        surface: 'sign-in submission',
        kind: LedgerRowKind.sequence,
        screen: '/login',
        declaredProvers: ['A3'],
        steps: ['tap', 'loading', 'resolve', 'navigate'],
      ),
    ],
    greenBehaviors: const {'A1', 'A2', 'A3', 'A4', 'A5'},
  );

  final honestDealList = TypedLedgerBuilder.derive(
    declared: [
      const DeclaredLedgerRow(
        surface: 'deal row title',
        kind: LedgerRowKind.presence,
        screen: '/deal_list',
        declaredProvers: ['B1'],
      ),
      const DeclaredLedgerRow(
        surface: 'load-more button',
        kind: LedgerRowKind.state,
        screen: '/deal_list',
        declaredProvers: ['B2'],
        attribute: 'onPressed = null @ end-of-list',
      ),
      const DeclaredLedgerRow(
        surface: 'empty-state banner',
        kind: LedgerRowKind.absence,
        screen: '/deal_list',
        declaredProvers: ['B3'],
        notRenderedIn: 'loaded',
      ),
      const DeclaredLedgerRow(
        surface: 'deal detail route',
        kind: LedgerRowKind.navigation,
        screen: '/deal_list',
        declaredProvers: ['B4'],
      ),
      const DeclaredLedgerRow(
        surface: 'pull-to-refresh',
        kind: LedgerRowKind.sequence,
        screen: '/deal_list',
        declaredProvers: ['B5'],
        steps: ['pull', 'loading', 'resolve'],
      ),
    ],
    greenBehaviors: const {'B1', 'B2', 'B3', 'B4', 'B5'},
  );

  // --- the gaming ledger FAILS the per-screen gate (AC-2) ----------------
  final gamingVerdict = TypedCoverageGate.evaluateScreens(
    feature: '004-login-ui',
    ledgerByScreen: {'/login': gamingLogin},
  );
  expect(gamingVerdict.feature, '004-login-ui');
  expect(gamingVerdict.passed, isFalse); // the gaming view FAILS
  expect(gamingVerdict.screens, hasLength(1));
  expect(gamingVerdict.gapScreens, hasLength(1));
  // the failure names the screen AND the four zero-traced kinds.
  final failures = gamingVerdict.failureLines().join('\n');
  expect(failures, contains('/login'));
  for (final label in ['absence', 'navigation', 'state', 'sequence']) {
    expect(
      failures,
      contains('kind "$label" has zero traced rows'),
      reason: label,
    );
  }
  // each gap carries a fix hint (issue #1143).
  expect(failures, contains('--> fix:'));
  expect(failures, contains('issue #1143'));
  // the JSON verdict records the screen + kind entries + outcome.
  final encoded = gamingVerdict.encode();
  expect(encoded, contains('"screen":"/login"'));
  expect(encoded, contains('"status":"partially-traced"'));
  expect(encoded, contains('"passed":false'));
  expect(gamingVerdict.summaryLine(), contains('outcome=gaps'));
  expect(gamingVerdict.summaryLine(), contains('screens=1'));

  // --- the honest five-kind screens PASS ---------------------------------
  final honestVerdict = TypedCoverageGate.evaluateScreens(
    feature: '004-login-ui',
    ledgerByScreen: {'/login': honestLogin, '/deal_list': honestDealList},
  );
  expect(honestVerdict.passed, isTrue);
  expect(honestVerdict.gapScreens, isEmpty);
  expect(honestVerdict.failureLines(), isEmpty);
  expect(honestVerdict.summaryLine(), contains('outcome=complete'));

  // --- a gaming screen next to a fully-traced one ------------------------
  final mixedVerdict = TypedCoverageGate.evaluateScreens(
    feature: '004-login-ui',
    ledgerByScreen: {'/login': gamingLogin, '/deal_list': honestDealList},
  );
  expect(mixedVerdict.passed, isFalse);
  expect(mixedVerdict.gapScreens.map((s) => s.screen), ['/login']);
  expect(mixedVerdict.gapScreens, isNot(contains(honestDealList)));

  // --- a row gap on an otherwise kind-complete screen still fails -------
  final rowGapLedger = TypedLedgerBuilder.derive(
    declared: [
      const DeclaredLedgerRow(
        surface: 'Sign In',
        kind: LedgerRowKind.presence,
        screen: '/login',
        declaredProvers: ['A1'],
      ),
      const DeclaredLedgerRow(
        surface: 'Email',
        kind: LedgerRowKind.presence,
        screen: '/login', // NO prover — a row gap
      ),
      const DeclaredLedgerRow(
        surface: 'error banner',
        kind: LedgerRowKind.absence,
        screen: '/login',
        declaredProvers: ['A2'],
        notRenderedIn: 'initial',
      ),
      const DeclaredLedgerRow(
        surface: 'deal_list',
        kind: LedgerRowKind.navigation,
        screen: '/login',
        declaredProvers: ['A4'],
      ),
      const DeclaredLedgerRow(
        surface: 'submit affordance',
        kind: LedgerRowKind.state,
        screen: '/login',
        declaredProvers: ['A5'],
        attribute: 'onPressed = null @ in-flight',
      ),
      const DeclaredLedgerRow(
        surface: 'sign-in submission',
        kind: LedgerRowKind.sequence,
        screen: '/login',
        declaredProvers: ['A3'],
        steps: ['tap', 'loading', 'resolve', 'navigate'],
      ),
    ],
    greenBehaviors: const {'A1', 'A2', 'A3', 'A4', 'A5'},
  );
  final rowGapVerdict = TypedCoverageGate.evaluateScreens(
    feature: '004-login-ui',
    ledgerByScreen: {'/login': rowGapLedger},
  );
  expect(rowGapVerdict.passed, isFalse); // row gaps count too
  expect(
    rowGapVerdict.failureLines().join('\n'),
    contains('"Email" (presence)'),
  );
  expect(
    rowGapVerdict.gapScreens.single.status,
    ScreenTraceStatus.partiallyTraced,
  );

  return null;
}
