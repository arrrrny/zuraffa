// Tests for TestListReader (spec 049-tdd-run, U1-U3 / T006).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('test_list_reader_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String> seed(String content) async {
    final dir = p.join(tmp.path, 'specs', '090-fixture');
    await Directory(p.join(dir, 'tdd')).create(recursive: true);
    await File(p.join(dir, 'tdd', 'test-list.md')).writeAsString(content);
    return dir;
  }

  test('U1: parses 4-column rows in list order', () async {
    final dir = await seed('''
# Test List: 090-fixture

## Outer loop: acceptance behaviors

One per acceptance criterion.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | first acceptance behavior | US1.AC1 | PENDING |
| A2 | second acceptance behavior | US1.AC2 | DONE |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | first unit behavior | FR-001 | RED |
| U2 | second unit behavior | FR-002 | GREEN |
''');

    final rows = await TestListReader(dir).read();

    expect(rows.map((r) => r.id), ['A1', 'A2', 'U1', 'U2']);
    expect(rows.first.description, 'first acceptance behavior');
    expect(rows.first.traces, 'US1.AC1');
    expect(rows.first.state, BehaviorState.pending);
    expect(rows[1].state, BehaviorState.done);
    expect(rows[2].state, BehaviorState.red);
    expect(rows[3].state, BehaviorState.green);
  });

  test('U2: kind is inferred from the section header', () async {
    final dir = await seed('''
# Test List: 090-fixture

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | an acceptance behavior | US1.AC1 | PENDING |

## Inner loop: unit behaviors

### `lib/src/some_file.dart`

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | a unit behavior | FR-001 | PENDING |

## Out of scope

Text, no table.
''');

    final rows = await TestListReader(dir).read();

    expect(rows, hasLength(2));
    expect(rows[0].id, 'A1');
    expect(rows[0].kind, BehaviorKind.acceptance);
    expect(rows[1].id, 'U1');
    expect(rows[1].kind, BehaviorKind.unit);
  });

  test('U3: a malformed row stops with an error naming the line', () async {
    // A 6-column row whose kind cell is neither acceptance/unit nor an
    // extension test shape (spec 050 FR-005) — no accepted dialect claims
    // it, so the reader stops naming the line. (`example` moved from
    // malformed to the 050 compat shim; the guard re-pointed here.)
    final dir = await seed('''
# Test List: 090-fixture

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | fine | FR-001 | PENDING |
| U2 | six column row | FR-002 | banana | PENDING |  |
''');

    await expectLater(
      TestListReader(dir).read(),
      throwsA(
        isA<TestListReadException>().having(
          (e) => e.message,
          'message',
          allOf(contains('line 8'), contains('U2')),
        ),
      ),
    );
  });

  test('U3: an unknown state cell is malformed', () async {
    final dir = await seed('''
## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | bad state | FR-001 | BLUE |
''');

    await expectLater(
      TestListReader(dir).read(),
      throwsA(
        isA<TestListReadException>().having(
          (e) => e.message,
          'message',
          allOf(contains('line 5'), contains('BLUE')),
        ),
      ),
    );
  });

  test(
    'a missing test list names the file and the producing command',
    () async {
      final dir = p.join(tmp.path, 'specs', 'no-list');

      await expectLater(
        TestListReader(dir).read(),
        throwsA(
          isA<TestListReadException>().having(
            (e) => e.message,
            'message',
            allOf(contains('test-list.md'), contains('zfa tdd plan')),
          ),
        ),
      );
    },
  );

  // -------------------------------------------------------------------
  // Bug #617 — the one-parser contract: the deprecated 6-column gen
  // dialect is accepted through a compat shim (kind cell wins, target
  // defaults moved into the reader); anything that is neither the
  // canonical 4-column shape nor a usable 6-column row stays malformed.
  // -------------------------------------------------------------------

  test(
    '617-shim: deprecated 6-column rows parse with kind from the cell',
    () async {
      final dir = await seed('''
# Test List: 090-fixture

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| B-001 | legacy acceptance row | US1.AC1 | acceptance | PENDING | |
| B-002 | legacy unit row | FR-001 | unit | GREEN | sampleSubject |
''');

      final rows = await TestListReader(dir).read();

      expect(rows.map((r) => r.id), ['B-001', 'B-002']);
      expect(rows[0].kind, BehaviorKind.acceptance);
      expect(rows[0].traces, 'US1.AC1');
      expect(rows[0].state, BehaviorState.pending);
      // Empty target cell → the reader's default (gen's old rule).
      expect(rows[0].target, 'subject_b_001');
      expect(rows[1].kind, BehaviorKind.unit);
      expect(rows[1].state, BehaviorState.green);
      // An explicit function-name target is kept verbatim.
      expect(rows[1].target, 'sampleSubject');
    },
  );

  test(
    '617-shim: path-like target cells fall back to subject_<snake-id>',
    () async {
      final dir = await seed('''
## Inner loop: unit behaviors

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| B-003 | path-like target | FR-009 | unit | PENDING | test/tdd/b_003_test.dart |
| B-004 | runnable-name target | FR-010 | unit | PENDING | a_test.dart::B-004::x |
''');

      final rows = await TestListReader(dir).read();

      expect(rows[0].target, 'subject_b_003');
      expect(rows[1].target, 'subject_b_004');
    },
  );

  test(
    '617-shim: a 6-column row with an unusable kind cell stays malformed',
    () async {
      final dir = await seed('''
## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | fine | FR-001 | PENDING |
| U2 | six column row | FR-002 | banana | PENDING |  |
''');

      await expectLater(
        TestListReader(dir).read(),
        throwsA(
          isA<TestListReadException>().having(
            (e) => e.message,
            'message',
            allOf(contains('line 6'), contains('U2')),
          ),
        ),
      );
    },
  );

  test(
    '617-shim: a 6-column row with an unknown state stays malformed',
    () async {
      final dir = await seed('''
## Inner loop: unit behaviors

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| U1 | bad state | FR-001 | unit | BLUE | x |
''');

      await expectLater(
        TestListReader(dir).read(),
        throwsA(
          isA<TestListReadException>().having(
            (e) => e.message,
            'message',
            contains('BLUE'),
          ),
        ),
      );
    },
  );

  test('617-shim: a 4-column row outside a section stays malformed', () async {
    final dir = await seed('''
# Test List: 090-fixture

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | orphaned row | FR-001 | PENDING |
''');

    await expectLater(
      TestListReader(dir).read(),
      throwsA(
        isA<TestListReadException>().having(
          (e) => e.message,
          'message',
          allOf(contains('line 5'), contains('outer/inner loop')),
        ),
      ),
    );
  });

  test(
    '617-contract: canonical 4-column rows resolve the default target',
    () async {
      final dir = await seed('''
## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | first acceptance behavior | US1.AC1 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | first unit behavior | FR-001 | PENDING |
''');

      final rows = await TestListReader(dir).read();

      // The 4-column shape carries no target: the reader defaults it the
      // way gen's private parser used to (bug #617 unification).
      expect(rows[0].target, 'subject_a1');
      expect(rows[1].target, 'subject_u1');
    },
  );

  // -------------------------------------------------------------------
  // Spec 050 (FR-007) — the extension's own hand-written dialect: the
  // kind cell names the test SHAPE (`example`), not the loop, so the
  // loop kind comes from the section header (as in the canonical shape)
  // and the last cell is a test reference (path-like -> default target).
  // -------------------------------------------------------------------

  test('050: an extension-dialect row in the outer section resolves '
      'acceptance kind and the default target', () async {
    final dir = await seed('''
## Outer loop: acceptance behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1 | hand-written acceptance row | US1.AC1 | example | PENDING | sc_001_test.dart::A1 |
''');

    final rows = await TestListReader(dir).read();

    expect(rows, hasLength(1));
    expect(rows[0].id, 'A1');
    // Kind comes from the SECTION header, not the `example` cell.
    expect(rows[0].kind, BehaviorKind.acceptance);
    expect(rows[0].traces, 'US1.AC1');
    expect(rows[0].state, BehaviorState.pending);
    // The path-like test-reference cell -> the default target.
    expect(rows[0].target, 'subject_a1');
  });

  test('050: an extension-dialect row in the inner section resolves '
      'unit kind and the default target', () async {
    final dir = await seed('''
## Inner loop: unit behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | hand-written unit row | FR-007 | example | DONE | test_list_reader_test.dart::U1 |
''');

    final rows = await TestListReader(dir).read();

    expect(rows, hasLength(1));
    expect(rows[0].id, 'U1');
    expect(rows[0].kind, BehaviorKind.unit);
    expect(rows[0].state, BehaviorState.done);
    expect(rows[0].target, 'subject_u1');
  });

  test(
    '050: an extension-dialect row outside any section stays malformed',
    () async {
      final dir = await seed('''
# Test List: 090-fixture

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | orphaned extension row | FR-005 | example | PENDING |  |
''');

      await expectLater(
        TestListReader(dir).read(),
        throwsA(
          isA<TestListReadException>().having(
            (e) => e.message,
            'message',
            allOf(contains('line 5'), contains('outer/inner loop')),
          ),
        ),
      );
    },
  );

  test('050: every extension test shape is accepted', () async {
    final shapes = [
      'example',
      'property',
      'contract',
      'approval',
      'characterization',
    ];
    for (final shape in shapes) {
      final dir = await seed('''
## Inner loop: unit behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | shape $shape row | FR-007 | $shape | PENDING | t.dart::U1 |
''');

      final rows = await TestListReader(dir).read();

      expect(rows, hasLength(1), reason: 'shape "$shape" must be accepted');
      expect(rows[0].kind, BehaviorKind.unit, reason: shape);
      expect(rows[0].target, 'subject_u1', reason: shape);
    }
  });

  test('050: markdown-escaped pipes in cells stay cell content '
      '(specs/049 U15 shape)', () async {
    // Verbatim shape of specs/049-tdd-run/tdd/test-list.md line 72: the
    // behavior text contains `outcome=clean\|refactored` — a markdown
    // escaped pipe. Splitting on raw `|` mis-counts 7 data columns.
    final dir = await seed('''
## Inner loop: unit behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U15 | refactor succeeds only on exit 0 AND `outcome=clean\\|refactored` | FR-002 | example | DONE | `test/plugins/tdd/services/step_runner_test.dart::U15: refactor succeeds on outcome=clean or outcome=refactored` |
''');

    final rows = await TestListReader(dir).read();

    expect(rows, hasLength(1));
    expect(rows[0].id, 'U15');
    // The escaped pipe survives as cell CONTENT, unescaped.
    expect(rows[0].description, contains('clean|refactored'));
    expect(rows[0].traces, 'FR-002');
    expect(rows[0].kind, BehaviorKind.unit);
    expect(rows[0].state, BehaviorState.done);
    expect(
      rows[0].target,
      'subject_u15',
      reason: 'the test cell is path-like -> the default target',
    );
  });

  // -------------------------------------------------------------------
  // Spec 050 (SC-002 / U9) — the repo's OWN hand-written lists must
  // resolve through the reader: a future dialect change that re-bricks
  // the repo's completed features fails here, fast.
  // -------------------------------------------------------------------

  test('050: the repo\'s real specs/044-049 test lists resolve through the '
      'reader (regression guard)', () async {
    final repoRoot = _findRepoRoot();
    const features = [
      '044-test-tdd-generation',
      '046-tdd-verify-red',
      '047-tdd-make',
      '048-tdd-refactor',
      '049-tdd-run',
    ];
    for (final feature in features) {
      final featureDir = p.join(repoRoot, 'specs', feature);
      final rows = await TestListReader(featureDir).read();
      expect(
        rows,
        isNotEmpty,
        reason: 'specs/$feature/tdd/test-list.md must resolve rows',
      );
      // Every row resolves a usable kind and a non-empty target
      // (the driver's minimum for a resolvable behavior).
      for (final row in rows) {
        expect(row.target, isNotEmpty, reason: 'specs/$feature ${row.id}');
      }
      // The two real dialects in the wild, both accepted:
      // 044 uses the acceptance/unit kind cell; 046-049 use the
      // extension test shapes (example).
    }
    // specs/049 is the issue's own repro target: its 42 rows (including
    // the escaped-pipe U15) all resolve.
    final rows049 = await TestListReader(
      p.join(repoRoot, 'specs', '049-tdd-run'),
    ).read();
    expect(rows049.map((r) => r.id), containsAll(['A1', 'U1', 'U15']));
    expect(rows049.first.kind, BehaviorKind.acceptance);
    expect(rows049.firstWhere((r) => r.id == 'U15').kind, BehaviorKind.unit);
  });

  group('bug 829: the Key entities section', () {
    test('read() skips the Key entities section instead of rejecting its '
        'rows as malformed', () async {
      final dir = await seed('''
# Test List: 090-fixture

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | first unit behavior | FR-001 | PENDING |

## Key entities

| entity | fields |
| ------ | ------ |
| User | name: String, email: String |
''');

      final rows = await TestListReader(dir).read();

      expect(rows.map((r) => r.id), ['U1']);
    });

    test('readEntities() parses entity names and field lists', () async {
      final dir = await seed('''
# Test List: 090-fixture

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | first unit behavior | FR-001 | PENDING |

## Key entities

| entity | fields |
| ------ | ------ |
| User | name: String, email: String |
| Role | |
''');

      final entities = await TestListReader(dir).readEntities();

      expect(entities.length, 2);
      expect(entities[0].name, 'User');
      // Fields normalize to the `--field` argv shape (no spaces).
      expect(entities[0].fields, ['name:String', 'email:String']);
      expect(entities[1].name, 'Role');
      expect(entities[1].fields, isEmpty);
    });

    test('readEntities() returns empty for a test list without the '
        'section (every pre-829 list is untouched)', () async {
      final dir = await seed('''
# Test List: 090-fixture

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | first unit behavior | FR-001 | PENDING |
''');

      expect(await TestListReader(dir).readEntities(), isEmpty);
    });
  });

  group('platform kind (issue #831, bug tdd-platform-channel-fake)', () {
    test(
      'platform harness section header sets kind=platform for 4-column rows',
      () async {
        final dir = await seed('''
# Test List: 013-barcode-fixture

## Platform harness: channel behaviors (issue #831)

Behaviors that sit on platform channels (camera, barcode, permissions,
notifications, location) and are expressed through certified fakes.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| T1 | scans a barcode and returns the decoded payload | SC-001 | PENDING |
| T2 | requests camera permission and honors the granted state | SC-002 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | unrelated unit behavior | FR-001 | PENDING |
''');

        final rows = await TestListReader(dir).read();

        expect(rows, hasLength(3));
        expect(rows[0].id, 'T1');
        expect(rows[0].kind, BehaviorKind.platform);
        expect(rows[1].id, 'T2');
        expect(rows[1].kind, BehaviorKind.platform);
        expect(rows[2].id, 'U1');
        expect(rows[2].kind, BehaviorKind.unit);
        expect(rows[0].state, BehaviorState.pending);
        expect(rows[0].target, 'subject_t1');
      },
    );

    test(
      'platform kind cell wins in the 6-column gen-legacy dialect',
      () async {
        final dir = await seed('''
# Test List for platform fixture

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| T1 | scans a barcode and returns the decoded payload | SC-001 | platform | PENDING | channel_scanner |
''');

        final rows = await TestListReader(dir).read();

        expect(rows, hasLength(1));
        expect(rows[0].id, 'T1');
        expect(rows[0].kind, BehaviorKind.platform);
        expect(rows[0].target, 'channel_scanner');
      },
    );

    test(
      'a section reset clears the platform kind (orphan rows reject)',
      () async {
        final dir = await seed('''
# Test List for platform fixture

## Platform harness: channel behaviors (issue #831)

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| T1 | scans a barcode and returns the decoded payload | SC-001 | PENDING |

## Notes

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| X1 | orphan row outside a behavior section | SC-001 | PENDING |
''');

        expect(
          () => TestListReader(dir).read(),
          throwsA(
            isA<TestListReadException>().having(
              (e) => e.message,
              'message',
              contains('X1'),
            ),
          ),
        );
      },
    );
  });
}

/// Walk up from the CWD to the repo root (the pubspec named `zuraffa`).
String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zuraffa')) {
      return dir.path;
    }
    if (dir.path == dir.parent.path) {
      throw StateError('cannot locate the zuraffa repo root');
    }
    dir = dir.parent;
  }
}
