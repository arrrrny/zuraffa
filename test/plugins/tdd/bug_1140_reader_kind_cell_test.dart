// Issue #1140 — reader-level pins for the finder-kind column.
//
// The red suite (bug_1140_finder_kind_plan_column_test.dart) proved the
// wire-in through the CLI. These pins lock the reader's parse contract
// itself: which 6-cell rows parse, what lands on
// [BehaviorRow.finderKinds], what is refused, and what stays null for
// the legacy shapes. They reference the new row field, so they compile
// only against the fixed tree — they are green-phase pins, not red
// evidence.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/finder_taxonomy.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('bug1140_reader_');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  Future<List<BehaviorRow>> read(String list) async {
    Directory(p.join(dir.path, 'tdd')).createSync(recursive: true);
    await File(p.join(dir.path, 'tdd', 'test-list.md')).writeAsString(list);
    return TestListReader(dir.path).read();
  }

  group('the 5-data-column kind shape parses (issue #1140)', () {
    test('kind cells become declared finderKinds', () async {
      final rows = await read('''
## Outer loop: widget behaviors

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |
| A1 | shows the 'Sign in' title and hides the 'Invalid credentials' banner | presence, absence | AC-1 | PENDING |
| A2 | the app navigates to the route 'deal_list' | route-outcome | AC-2 | PENDING |
| A3 | while sign-in is in flight, shows 'Signing in' and disables the 'Sign in' button | presence, enabled-state, sequence | AC-3 | PENDING |
| A5 | renders the brand theme | none | AC-5 | PENDING |
''');
      expect(
        rows.map((r) => r.finderKinds),
        everyElement(isNotNull),
        reason: 'every row above carries the kind column',
      );
      expect(
        rows[0].finderKinds,
        unorderedEquals(<ScenarioAssertionClass>[
          ScenarioAssertionClass.presence,
          ScenarioAssertionClass.absence,
        ]),
      );
      expect(rows[1].finderKinds, <ScenarioAssertionClass>[
        ScenarioAssertionClass.routeOutcome,
      ]);
      expect(
        rows[2].finderKinds,
        unorderedEquals(<ScenarioAssertionClass>[
          ScenarioAssertionClass.presence,
          ScenarioAssertionClass.enabledState,
          ScenarioAssertionClass.sequence,
        ]),
      );
      expect(rows[3].finderKinds, isEmpty, reason: '`none` = declared empty');
      // The row shape keeps its other cells positionally intact.
      expect(rows[1].traces, 'AC-2');
      expect(rows[1].kind.name, 'widget');
      expect(rows[1].state.name, 'pending');
    });

    test('the kind cell is case- and whitespace-tolerant', () async {
      final rows = await read('''
## Outer loop: widget behaviors

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |
| A2 | the app navigates to the route 'deal_list' |  Route-Outcome | AC-2 | PENDING |
''');
      expect(rows.single.finderKinds, <ScenarioAssertionClass>[
        ScenarioAssertionClass.routeOutcome,
      ]);
    });

    test('an unknown token is a malformed row naming the vocabulary', () async {
      await expectLater(
        read('''
## Outer loop: widget behaviors

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |
| A2 | the app navigates to the route 'deal_list' | bogus | AC-2 | PENDING |
'''),
        throwsA(
          isA<TestListReadException>().having(
            (e) => e.message,
            'message',
            allOf(contains('bogus'), contains('route-outcome')),
          ),
        ),
      );
    });

    test(
      'a 6-cell row whose 4th cell is no kind cell stays malformed',
      () async {
        // A legacy 7-cell row that lost its trailing pipe must not be
        // mis-read as the kind shape: 'widget' is a LOOP kind, not a
        // finder kind.
        await expectLater(
          read('''
## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A2 | renders the brand theme | AC-2 | widget | PENDING |
'''),
          throwsA(isA<TestListReadException>()),
        );
      },
    );
  });

  group('legacy shapes keep finderKinds null (back-compat)', () {
    test('a 4-column row parses with no declared kinds', () async {
      final rows = await read('''
## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | renders the brand theme | AC-1 | PENDING |
''');
      expect(rows.single.finderKinds, isNull);
    });

    test(
      'the deprecated 7-cell dialect parses with no declared kinds',
      () async {
        final rows = await read('''
## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A2 | renders the brand theme | AC-2 | widget | PENDING | |
''');
        final a2 = rows.where((r) => r.id == 'A2').single;
        expect(a2.kind.name, 'widget');
        expect(a2.finderKinds, isNull);
      },
    );
  });

  group('FinderTaxonomy kind-cell helpers (issue #1140)', () {
    test('kindCellFor renders the canonical vocabulary', () {
      expect(
        FinderTaxonomy.kindCellFor(
          'the app navigates to the route "deal_list"',
        ),
        'route-outcome',
      );
      expect(
        FinderTaxonomy.kindCellFor("shows the 'Add to cart' action"),
        'presence',
      );
      expect(FinderTaxonomy.kindCellFor('renders the dashboard shell'), 'none');
      // Multi-kind scenarios render comma-joined in enum order.
      expect(
        FinderTaxonomy.kindCellFor(
          'while sign-in is in flight, shows "Signing in" and disables the '
          '"Sign in" button',
        ),
        'presence, enabled-state, sequence',
      );
    });

    test('kindCellFor and tryParseKindCell round-trip', () {
      const scenarios = <String>[
        "shows the 'Add to cart' action",
        'the error banner hides "An error occurred" after a retry',
        'the app navigates to the route "deal_list"',
        'disables the "Save" button and enables the "Delete" button',
        'while sign-in is in flight, shows "Signing in"',
        'renders the dashboard shell',
      ];
      for (final scenario in scenarios) {
        final cell = FinderTaxonomy.kindCellFor(scenario);
        final parsed = FinderTaxonomy.tryParseKindCell(cell);
        expect(parsed, isNotNull, reason: 'cell: $cell');
        expect(
          FinderTaxonomy.predictedKinds(scenario),
          parsed,
          reason: 'round-trip preserves the predicted kinds: $cell',
        );
      }
    });

    test('tryParseKindCell rejects unknown tokens', () {
      expect(FinderTaxonomy.tryParseKindCell('bogus'), isNull);
      expect(FinderTaxonomy.tryParseKindCell('presence, bogus'), isNull);
      // `none` and empties are the declared-nothing shape.
      expect(FinderTaxonomy.tryParseKindCell('none'), isEmpty);
      expect(FinderTaxonomy.tryParseKindCell(''), isEmpty);
    });

    test('predictedKinds includes the sequence marker for in-flight '
        'clauses', () {
      expect(
        FinderTaxonomy.predictedKinds(
          'while sign-in is in flight, shows "Signing in"',
        ),
        unorderedEquals(<ScenarioAssertionClass>{
          ScenarioAssertionClass.presence,
          ScenarioAssertionClass.sequence,
        }),
      );
    });
  });
}
