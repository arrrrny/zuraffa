// Subject T7 (spec 1334, issue #1143): strength pins for the per-screen
// report and the JSON round-trip — enumeration order, status polarity,
// zeroTraced vs untraced, HIGHLIGHT polarity, and the legacy/typed
// classification seams.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';

Object? subject_t7() {
  // --- enumeration pin: exactly five, ordered ----------------------------
  expect(LedgerRowKind.values.map((k) => k.label).toList(), [
    'presence',
    'absence',
    'navigation',
    'state',
    'sequence',
  ]);

  // --- the per-screen report shape: always five entries ------------------
  final emptyReport = TypedLedgerBuilder.screenReports({
    '/nowhere': TypedLedgerBuilder.derive(
      declared: const [],
      greenBehaviors: const {},
    ),
  });
  final nowhere = emptyReport['/nowhere']!;
  expect(nowhere.coverage, hasLength(5)); // even an empty screen lists 5
  expect(nowhere.coverage.map((c) => c.label).toList(), [
    'presence 0/0',
    'absence 0/0',
    'navigation 0/0',
    'state 0/0',
    'sequence 0/0',
  ]);
  expect(nowhere.status, ScreenTraceStatus.untraced);

  // --- zeroTraced vs untraced polarity ------------------------------------
  // 0/0: zeroTraced (the #1143 gap predicate) but NOT untraced (the 0966
  // declared-kinds predicate requires total > 0).
  final zeroEntry = nowhere.coverage.first;
  expect(zeroEntry.zeroTraced, isTrue);
  expect(zeroEntry.untraced, isFalse);
  expect(zeroEntry.complete, isFalse);
  // 0/1: both predicates fire.
  final declaredUntraced = TypedLedgerBuilder.kindCoverageAllKinds(
    TypedLedgerBuilder.derive(
      declared: const [
        DeclaredLedgerRow(surface: 'error banner', kind: LedgerRowKind.absence),
      ],
      greenBehaviors: const {},
    ),
  );
  final absenceEntry = declaredUntraced.singleWhere(
    (c) => c.kind == LedgerRowKind.absence,
  );
  expect(absenceEntry.label, 'absence 0/1');
  expect(absenceEntry.zeroTraced, isTrue);
  expect(absenceEntry.untraced, isTrue); // declared AND untraced
  // 1/1: neither.
  final tracedEntry = TypedLedgerBuilder.kindCoverageAllKinds(
    TypedLedgerBuilder.derive(
      declared: const [
        DeclaredLedgerRow(
          surface: 'Sign In',
          kind: LedgerRowKind.presence,
          declaredProvers: ['A1'],
        ),
      ],
      greenBehaviors: const {'A1'},
    ),
  ).singleWhere((c) => c.kind == LedgerRowKind.presence);
  expect(tracedEntry.label, 'presence 1/1');
  expect(tracedEntry.zeroTraced, isFalse);
  expect(tracedEntry.untraced, isFalse);
  expect(tracedEntry.complete, isTrue);

  // --- status polarity: row gaps without kind gaps -----------------------
  // Every kind has a traced row, but one extra presence row is red: the
  // screen is PARTIALLY traced (not fully — row gaps count).
  final rowGapScreen = TypedLedgerBuilder.screenReports({
    '/login': TypedLedgerBuilder.derive(
      declared: [
        const DeclaredLedgerRow(
          surface: 'Sign In',
          kind: LedgerRowKind.presence,
          declaredProvers: ['A1'],
        ),
        const DeclaredLedgerRow(
          surface: 'Email', // red row
          kind: LedgerRowKind.presence,
        ),
        const DeclaredLedgerRow(
          surface: 'error banner',
          kind: LedgerRowKind.absence,
          declaredProvers: ['A2'],
          notRenderedIn: 'initial',
        ),
        const DeclaredLedgerRow(
          surface: 'deal_list',
          kind: LedgerRowKind.navigation,
          declaredProvers: ['A4'],
        ),
        const DeclaredLedgerRow(
          surface: 'submit affordance',
          kind: LedgerRowKind.state,
          declaredProvers: ['A5'],
          attribute: 'onPressed = null @ in-flight',
        ),
        const DeclaredLedgerRow(
          surface: 'sign-in submission',
          kind: LedgerRowKind.sequence,
          declaredProvers: ['A3'],
          steps: ['tap', 'loading', 'resolve', 'navigate'],
        ),
      ],
      greenBehaviors: const {'A1', 'A2', 'A3', 'A4', 'A5'},
    ),
  });
  final rowGapReport = rowGapScreen['/login']!;
  expect(rowGapReport.zeroTracedKinds, isEmpty); // all five kinds traced
  expect(rowGapReport.hasRowGaps, isTrue); // but one row is red
  expect(rowGapReport.status, ScreenTraceStatus.partiallyTraced); // NOT full
  expect(rowGapReport.fullyTraced, isFalse);
  expect(rowGapReport.rowGaps, hasLength(1));
  expect(rowGapReport.rowGaps.single, contains('Email'));

  // --- the typed JSON round-trip: screen + advisory + semantics survive --
  final typedLedger = TypedLedgerBuilder.derive(
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
        surface: 'login view matches the golden',
        kind: LedgerRowKind.presence, // advisory golden: presence + flag
        screen: '/login',
        advisory: true,
        platformTolerance: {'ios': 0.5, 'android': 1.0},
      ),
      const DeclaredLedgerRow(
        surface: 'sign-in submission',
        kind: LedgerRowKind.sequence,
        screen: '/login',
        declaredProvers: ['A3'],
        steps: ['tap', 'loading', 'resolve', 'navigate'],
      ),
    ],
    greenBehaviors: const {'A1', 'A2', 'A3'},
  );
  final typedJson = TypedLedgerBuilder.toJson(typedLedger);
  expect(typedJson, contains('"screen":"/login"'));
  expect(typedJson, contains('"advisory":true'));
  expect(typedJson, contains('"platformTolerance":{"ios":0.5'));

  final reparsed = TypedLedgerBuilder.fromLedgerJson(typedJson);
  expect(reparsed.legacy, isFalse); // typed labels present
  expect(reparsed.rows, hasLength(4));
  // screen, kind, advisory, and semantics all survive the round-trip.
  expect(reparsed.rows.where((r) => r.screen == '/login'), hasLength(4));
  final reparsedGolden = reparsed.rows.singleWhere((r) => r.advisory);
  expect(reparsedGolden.kind, LedgerRowKind.presence);
  expect(reparsedGolden.platformTolerance['android'], 1.0);
  final reparsedAbsence = reparsed.rows.singleWhere(
    (r) => r.kind == LedgerRowKind.absence,
  );
  expect(reparsedAbsence.notRenderedIn, 'initial');
  expect(reparsedAbsence.state, 'DONE');
  final reparsedSequence = reparsed.rows.singleWhere(
    (r) => r.kind == LedgerRowKind.sequence,
  );
  expect(reparsedSequence.steps, ['tap', 'loading', 'resolve', 'navigate']);
  // the golden row's state recomputes red (no provers recorded).
  expect(reparsedGolden.state, 'NOT-DONE');

  // --- legacy/typed classification pins -----------------------------------
  // A ledger mixing typed + kindless rows is TYPED (any typed label wins);
  // the kindless row reclassifies presence.
  final mixedJson = jsonEncode([
    {
      'surface': 'Sign In',
      'kind': 'presence',
      'provenBy': ['A1'],
      'state': 'DONE',
    },
    {
      'surface': 'legacy affordance',
      'kind': 'affordance',
      'provenBy': [],
      'state': 'NOT-DONE',
    },
  ]);
  final mixed = TypedLedgerBuilder.fromLedgerJson(mixedJson);
  expect(mixed.legacy, isFalse);
  expect(mixed.rows[1].kind, LedgerRowKind.presence);
  expect(mixed.rows[1].state, 'NOT-DONE');

  // --- HIGHLIGHT polarity: zero-traced kinds only -------------------------
  final highlightScreen = TypedLedgerBuilder.screenReports({
    '/login': TypedLedgerBuilder.derive(
      declared: [
        const DeclaredLedgerRow(
          surface: 'Sign In',
          kind: LedgerRowKind.presence,
          screen: '/login',
          declaredProvers: ['A1'],
        ),
      ],
      greenBehaviors: const {'A1'},
    ),
  });
  final coverage = highlightScreen['/login']!.coverage;
  expect(coverage.where((c) => c.zeroTraced).map((c) => c.label).toList(), [
    'absence 0/0',
    'navigation 0/0',
    'state 0/0',
    'sequence 0/0',
  ]);
  expect(coverage.where((c) => !c.zeroTraced).map((c) => c.label).toList(), [
    'presence 1/1',
  ]);

  return null;
}
