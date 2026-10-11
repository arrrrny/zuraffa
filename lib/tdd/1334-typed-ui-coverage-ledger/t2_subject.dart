// Subject T2 (spec 1334, issue #1143): the per-screen kind report lists
// ALL FIVE kinds and counts ANY zero-traced kind as a gap.
//
// AC-2: "Any kind that has zero traced rows for a screen MUST be counted
// as a gap in the coverage report. A screen with only presence rows (no
// absence, navigation, state, sequence) shows as partially traced — not
// 100%." The gaming fixture: the all-9-literals-`Column` view — 9 presence
// rows green, nothing else anywhere.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';

Object? subject_t2() {
  // --- the gaming ledger: 9 presence rows, all green, one screen -------
  final gamingLedger = TypedLedgerBuilder.derive(
    declared: [
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
          screen: '/login',
          declaredProvers: ['A1'],
        ),
    ],
    greenBehaviors: const {'A1'},
  );

  // --- all five kinds, 0/0 included (AC-2) ------------------------------
  final coverage = TypedLedgerBuilder.kindCoverageAllKinds(
    gamingLedger,
    screen: '/login',
  );
  expect(coverage, hasLength(5)); // presence AND the four 0/0 kinds
  expect(coverage.map((c) => c.kind.label).toList(), [
    'presence',
    'absence',
    'navigation',
    'state',
    'sequence',
  ]);
  final presence = coverage.singleWhere(
    (c) => c.kind == LedgerRowKind.presence,
  );
  expect(presence.traced, 9);
  expect(presence.total, 9);
  expect(presence.label, 'presence 9/9');
  expect(presence.zeroTraced, isFalse);
  // the four kinds the plan never declared are STILL listed — and gaps.
  for (final label in ['absence', 'navigation', 'state', 'sequence']) {
    final entry = coverage.singleWhere((c) => c.kind.label == label);
    expect(entry.traced, 0, reason: label);
    expect(entry.total, 0, reason: label); // 0/0 — declared nowhere
    expect(entry.label, '$label 0/0', reason: label);
    expect(entry.zeroTraced, isTrue, reason: label); // zero traced = gap
    expect(entry.screen, '/login', reason: label);
  }

  // --- per-screen grouping ----------------------------------------------
  final byScreen = TypedLedgerBuilder.groupByScreen(gamingLedger);
  expect(byScreen.keys, ['/login']);
  expect(byScreen['/login'], hasLength(9));

  // --- the per-screen report: partially traced, NOT 100% ----------------
  final reports = TypedLedgerBuilder.screenReports(byScreen);
  final login = reports['/login']!;
  expect(login.screen, '/login');
  expect(login.screenLabel, '/login');
  expect(login.status, ScreenTraceStatus.partiallyTraced);
  expect(login.zeroTracedKinds.map((c) => c.kind.label).toList(), [
    'absence',
    'navigation',
    'state',
    'sequence',
  ]);
  expect(login.hasRowGaps, isFalse); // all 9 rows ARE green
  expect(login.fullyTraced, isFalse); // but the screen is NOT 100%
  expect(login.coverage, hasLength(5));

  // --- an untraced screen (zero traced rows anywhere) --------------------
  final untracedReports = TypedLedgerBuilder.screenReports({
    '/empty': TypedLedgerBuilder.derive(
      declared: [
        const DeclaredLedgerRow(
          surface: 'error banner',
          kind: LedgerRowKind.absence,
          screen: '/empty',
        ),
      ],
      greenBehaviors: const {},
    ),
  });
  final empty = untracedReports['/empty']!;
  expect(empty.status, ScreenTraceStatus.untraced);
  expect(empty.zeroTracedKinds, hasLength(5)); // every kind incl. presence
  expect(empty.hasRowGaps, isTrue);

  // --- the honest five-kind screen IS fully traced -----------------------
  final honestReports = TypedLedgerBuilder.screenReports({
    '/login': TypedLedgerBuilder.derive(
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
    ),
  });
  final honest = honestReports['/login']!;
  expect(honest.status, ScreenTraceStatus.fullyTraced);
  expect(honest.zeroTracedKinds, isEmpty);
  expect(honest.hasRowGaps, isFalse);
  expect(honest.fullyTraced, isTrue);

  return null;
}
