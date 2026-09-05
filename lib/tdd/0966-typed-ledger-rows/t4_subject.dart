// Subject T4 (spec 0966, issue #966): state rows — the widget attribute
// "buttons disabled while in flight" (FR-005-class) is traced end-to-end
// in the 004-login-ui corpus.
//
// A state row records the asserted attribute (FR-004). It is traced
// exactly when a green behavior asserts that attribute in the declared
// in-state; a "state" row with no recorded attribute is malformed and
// never counts as proof — the attribute is exactly what a presence row
// cannot express.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';

Object? subject_t4() {
  // --- plan time: the FR-005-class scenario yields a STATE row --------
  // The 004-login-ui FR-005: "the submit + continue affordances are
  // disabled while a submission is in flight". An attribute verb with
  // no interaction chain — state, not sequence (precedence, FR-005).
  final declared = <DeclaredLedgerRow>[
    DeclaredLedgerRow.fromScenario(
      surface: "Sign In",
      scenario: "shows the 'Sign In' title on the login view",
      declaredProvers: ['A1'],
    ),
    DeclaredLedgerRow.fromScenario(
      surface: 'submit + continue affordances',
      scenario:
          'the affordances are disabled while the submission is in flight',
      declaredProvers: ['A5'],
      attribute: 'onPressed = null @ in-flight',
    ),
  ];
  final stateRow = declared.last;
  expect(stateRow.kind, LedgerRowKind.state);
  expect(stateRow.surface, 'submit + continue affordances');
  expect(stateRow.attribute, 'onPressed = null @ in-flight');

  // --- traced end-to-end: green behavior + recorded attribute ---------
  final honest = TypedLedgerBuilder.derive(
    declared: declared,
    greenBehaviors: const {'A1', 'A5'}, // A5 asserts the disabled attribute
  );
  final traced = honest.singleWhere((r) => r.kind == LedgerRowKind.state);
  expect(traced.state, 'DONE');
  expect(traced.attribute, 'onPressed = null @ in-flight');

  // the verdict + artifacts carry the attribute (end-to-end, 004-login-ui).
  final verdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: honest,
  );
  expect(verdict.feature, '004-login-ui');
  expect(verdict.passed, isTrue);
  expect(
    verdict.encode(),
    contains('"attribute":"onPressed = null @ in-flight"'),
  );
  expect(
    TypedLedgerBuilder.toMarkdown(honest),
    contains('onPressed = null @ in-flight'),
  );

  // --- a malformed state row never counts as proof --------------------
  // A "state" row that never records the asserted attribute expresses
  // nothing a presence row does not: it stays NOT-DONE even with a
  // green prover, and the kind stays a gap (FR-004).
  final malformed = TypedLedgerBuilder.derive(
    declared: const [
      DeclaredLedgerRow(
        surface: 'submit + continue affordances',
        kind: LedgerRowKind.state,
        declaredProvers: ['A5'],
      ),
    ],
    greenBehaviors: const {'A5'},
  );
  final malformedRow = malformed.single;
  expect(malformedRow.state, 'NOT-DONE');
  expect(malformedRow.surface, 'submit + continue affordances');
  final malformedVerdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: malformed,
  );
  expect(malformedVerdict.feature, '004-login-ui');
  expect(malformedVerdict.passed, isFalse);
  expect(
    malformedVerdict.untracedKinds.map((c) => c.kind.label),
    contains('state'),
  );

  // --- FR-005-class end-to-end: the full honest 004-login-ui ledger ---
  // presence (9 literals) + absence + sequence + state all traced — the
  // behaviors FR-005 demands are EXPRESSIBLE in the typed schema and
  // each kind traces (the acceptance target).
  final fullLogin = <DeclaredLedgerRow>[
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
      declaredProvers: ['A2'],
      notRenderedIn: 'initial',
    ),
    const DeclaredLedgerRow(
      surface: 'sign-in submission',
      kind: LedgerRowKind.sequence,
      declaredProvers: ['A3'],
      steps: ['tap', 'loading', 'resolve', 'navigate'],
    ),
    const DeclaredLedgerRow(
      surface: 'submit + continue affordances',
      kind: LedgerRowKind.state,
      declaredProvers: ['A5'],
      attribute: 'onPressed = null @ in-flight',
    ),
  ];
  final fullLedger = TypedLedgerBuilder.derive(
    declared: fullLogin,
    greenBehaviors: const {'A1', 'A2', 'A3', 'A5'},
  );
  // every declared surface survives derivation verbatim.
  expect(fullLedger.map((r) => r.surface), [
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
    'submit + continue affordances',
  ]);
  final fullVerdict = TypedCoverageGate.evaluate(
    feature: '004-login-ui',
    rows: fullLedger,
  );
  expect(fullVerdict.feature, '004-login-ui');
  // FR-005-class behaviors are expressible and traced end-to-end.
  expect(fullVerdict.passed, isTrue);
  expect(fullVerdict.untracedKinds, isEmpty);
  expect(
    fullVerdict.kindCoverage.map((c) => c.kind.label),
    containsAll(['presence', 'absence', 'sequence', 'state']),
  );

  return null;
}
