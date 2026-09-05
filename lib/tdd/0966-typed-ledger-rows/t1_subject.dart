// Subject T1 (spec 0966, issue #966): the typed ledger row schema —
// kinds assigned at plan time from scenario verbs, and the typed gate
// flagging UNTRACED KINDS as gaps on the all-9-literals-`Column` view.
//
// The gaming view: a login-shaped feature whose plan declares the 9
// production literals (presence scenarios) plus absence and sequence
// scenarios ("error banner hidden until a failure occurs", "tap →
// loading → resolve → navigate"). A cheating ledger proves the 9
// presence rows green (the all-9-literals Column renders everything at
// once) while the absence + sequence rows go untraced. The typed gate
// must fail that ledger NAMING the kinds.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';

/// The 9 declared login literals (presence scenarios — the
/// 004-login-ui shape).
const scenarioVerbs = <String>[
  "shows the 'Sign In' title on the login view",
  "shows the 'Email' field label on the login view",
  "shows the 'Password' field label on the login view",
  "shows the 'Forgot password?' link on the login view",
  "shows the 'Sign In' submit affordance on the login view",
  "shows the 'Continue with Apple' affordance on the login view",
  "shows the 'Continue with Google' affordance on the login view",
  "shows the 'Create account' affordance on the login view",
  "shows the error banner text 'Invalid credentials' on the login view",
];

Object? subject_t1() {
  // --- plan time: kinds assigned from scenario verbs ------------------
  // The 9 literals are presence scenarios; the plan ALSO declares the
  // absence + sequence scenarios the issue pins (verbs decide, never
  // post hoc).
  final declared = <DeclaredLedgerRow>[
    for (final verb in scenarioVerbs)
      DeclaredLedgerRow.fromScenario(
        surface: RegExp(r"'([^']+)'").firstMatch(verb)!.group(1)!,
        scenario: verb,
        declaredProvers: ['A1'],
      ),
    DeclaredLedgerRow.fromScenario(
      surface: 'error banner',
      scenario:
          'the error banner is hidden until a failure occurs '
          '(not rendered in the initial state)',
      notRenderedIn: 'initial',
    ),
    DeclaredLedgerRow.fromScenario(
      surface: 'sign-in submission',
      scenario: 'tap the submit button → loading → resolve → navigate',
      steps: ['tap', 'loading', 'resolve', 'navigate'],
    ),
  ];

  // kinds are assigned at plan time from the verbs (FR-005).
  expect(
    declared.take(9).every((r) => r.kind == LedgerRowKind.presence),
    isTrue,
  );
  expect(declared[9].kind, LedgerRowKind.absence);
  expect(declared[10].kind, LedgerRowKind.sequence);
  // the plan pins the declared surfaces and the chain verbatim.
  expect(declared[9].surface, 'error banner');
  expect(declared[10].surface, 'sign-in submission');
  expect(declared[10].steps, ['tap', 'loading', 'resolve', 'navigate']);
  expect(declared.take(9).map((r) => r.surface), [
    'Sign In',
    'Email',
    'Password',
    'Forgot password?',
    'Sign In',
    'Continue with Apple',
    'Continue with Google',
    'Create account',
    'Invalid credentials',
  ]);

  // --- the gaming ledger: 9 presence rows green (all-9-literals Column)
  final gamingLedger = TypedLedgerBuilder.derive(
    declared: declared,
    greenBehaviors: const {'A1'}, // the Column view's presence behavior
  );

  // presence is fully traced; absence + sequence have no green prover.
  final gamingCoverage = TypedLedgerBuilder.kindCoverage(gamingLedger);
  final presenceCoverage = gamingCoverage.singleWhere(
    (c) => c.kind == LedgerRowKind.presence,
  );
  expect(presenceCoverage.traced, 9);
  expect(presenceCoverage.total, 9);
  final absenceCoverage = gamingCoverage.singleWhere(
    (c) => c.kind == LedgerRowKind.absence,
  );
  expect(absenceCoverage.untraced, isTrue);
  final sequenceCoverage = gamingCoverage.singleWhere(
    (c) => c.kind == LedgerRowKind.sequence,
  );
  expect(sequenceCoverage.untraced, isTrue);

  // --- the typed gate flags the UNTRACED KINDS as gaps ----------------
  final verdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: gamingLedger,
  );
  expect(verdict.feature, '004-login-ui');
  expect(verdict.passed, isFalse); // the gaming view FAILS the gate
  expect(
    verdict.untracedKinds.map((c) => c.kind.label),
    containsAll(['absence', 'sequence']),
  );
  expect(
    verdict.kindGaps.join(' '),
    contains('kind "absence" declared but untraced'),
  );
  expect(
    verdict.kindGaps.join(' '),
    contains('kind "sequence" declared but untraced'),
  );
  // the failure names the kinds with a fix hint
  expect(verdict.failureLines().join(' '), contains('--> fix:'));

  return null;
}
