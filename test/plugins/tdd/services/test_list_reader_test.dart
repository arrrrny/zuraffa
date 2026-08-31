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
}
