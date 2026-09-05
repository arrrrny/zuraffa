// Subject T5 (spec 0966, issue #966): the XRay overlay renders KIND
// coverage, not just surface coverage — and the all-9-literals-`Column`
// view shows as PARTIALLY traced.
//
// The #963 overlay painted by ledger state only (proven clean / unproven
// highlighted). A presence-only ledger painted all-clean. With typed
// rows the overlay distinguishes kind coverage PER SCREEN: every
// declared kind with its traced/total counts; untraced kinds highlight
// (never painted as proof); the deck lists kind entries naming them.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

Object? subject_t5() {
  // --- the all-9-literals-Column gaming ledger (per screen) -----------
  final declared = <DeclaredLedgerRow>[
    for (final literal in const [
      'Sign In',
      'Email',
      'Password',
      'Forgot password?',
      'Sign In submit',
      'Continue with Apple',
      'Continue with Google',
      'Create account',
      'Invalid credentials',
    ])
      DeclaredLedgerRow(
        surface: literal,
        kind: LedgerRowKind.presence,
        declaredProvers: ['A1'],
      ),
    const DeclaredLedgerRow(
      surface: 'error banner',
      kind: LedgerRowKind.absence,
      notRenderedIn: 'initial',
    ),
    const DeclaredLedgerRow(
      surface: 'sign-in submission',
      kind: LedgerRowKind.sequence,
      steps: ['tap', 'loading', 'resolve', 'navigate'],
    ),
  ];
  final gamingLedger = TypedLedgerBuilder.derive(
    declared: declared,
    greenBehaviors: const {'A1'},
  );
  // the declared surfaces survive derivation verbatim (the 9 literals
  // plus the absence and sequence surfaces).
  expect(gamingLedger.map((r) => r.surface), [
    'Sign In',
    'Email',
    'Password',
    'Forgot password?',
    'Sign In submit',
    'Continue with Apple',
    'Continue with Google',
    'Create account',
    'Invalid credentials',
    'error banner',
    'sign-in submission',
  ]);
  expect(
    gamingLedger.singleWhere((r) => r.kind == LedgerRowKind.sequence).steps,
    ['tap', 'loading', 'resolve', 'navigate'],
  );

  // --- the overlay renders kind coverage for the screen ---------------
  final loginCoverage = XrayLedgerOverlay.kindCoverage(
    gamingLedger,
    screen: '/login',
  );
  final presence = loginCoverage.singleWhere(
    (c) => c.kind == LedgerRowKind.presence,
  );
  expect(presence.screen, '/login');
  expect(presence.traced, 9);
  expect(presence.total, 9);
  expect(presence.complete, isTrue);
  // absence + sequence: UNTRACED — highlighted, never painted as proof.
  expect(
    loginCoverage.where((c) => c.untraced).map((c) => c.kind.label),
    containsAll(['absence', 'sequence']),
  );
  // the labels read as counts (the deck shape).
  expect(
    loginCoverage.map((c) => c.label),
    containsAll(['presence 9/9', 'absence 0/1', 'sequence 0/1']),
  );

  // a presence-only screen shows as PARTIALLY traced.
  expect(XrayLedgerOverlay.partiallyTraced(loginCoverage), isTrue);

  // --- the overlay distinguishes kind coverage PER SCREEN -------------
  // /deal_list traces presence + state only; /login is the gaming view.
  final dealLedger = TypedLedgerBuilder.derive(
    declared: const [
      DeclaredLedgerRow(
        surface: 'deal row title',
        kind: LedgerRowKind.presence,
        declaredProvers: ['B1'],
      ),
      DeclaredLedgerRow(
        surface: 'load-more button',
        kind: LedgerRowKind.state,
        declaredProvers: ['B2'],
        attribute: 'onPressed = null @ end-of-list',
      ),
    ],
    greenBehaviors: const {'B1', 'B2'},
  );
  expect(dealLedger.map((r) => r.surface), [
    'deal row title',
    'load-more button',
  ]);
  expect(
    dealLedger.singleWhere((r) => r.kind == LedgerRowKind.state).attribute,
    'onPressed = null @ end-of-list',
  );
  final byScreen = XrayLedgerOverlay.kindCoverageByScreen({
    '/login': gamingLedger,
    '/deal_list': dealLedger,
  });
  expect(byScreen, hasLength(2));
  expect(byScreen['/login']!.map((c) => c.screen), everyElement('/login'));
  expect(
    byScreen['/deal_list']!.map((c) => c.screen),
    everyElement('/deal_list'),
  );
  expect(
    byScreen['/login']!.where((c) => c.untraced).map((c) => c.kind.label),
    containsAll(['absence', 'sequence']),
  );
  // /deal_list: every declared kind traced — clean there.
  expect(byScreen['/deal_list']!.every((c) => !c.untraced), isTrue);
  // the /login screen highlights exactly the untraced kinds.
  expect(
    XrayLedgerOverlay.untracedKindLabels(byScreen['/login']!),
    containsAll(['absence', 'sequence']),
  );
  expect(
    XrayLedgerOverlay.untracedKindLabels(byScreen['/deal_list']!),
    isEmpty,
  );

  // --- the deck lists kind entries with counts, naming untraced kinds -
  final deckEntries = XrayLedgerDeck.kindEntries(gamingLedger);
  expect(
    deckEntries.map((e) => e.label),
    containsAll(['presence 9/9', 'absence 0/1', 'sequence 0/1']),
  );
  expect(
    deckEntries.singleWhere((e) => e.label == 'absence 0/1').state,
    'NOT-DONE',
  );
  expect(
    deckEntries.singleWhere((e) => e.label == 'presence 9/9').state,
    'DONE',
  );

  // --- and the gate still fails the all-9-literals view ---------------
  final verdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: gamingLedger,
  );
  expect(verdict.feature, '004-login-ui');
  expect(verdict.passed, isFalse);
  expect(
    verdict.untracedKinds.map((c) => c.kind.label),
    containsAll(['absence', 'sequence']),
  );

  return null;
}
