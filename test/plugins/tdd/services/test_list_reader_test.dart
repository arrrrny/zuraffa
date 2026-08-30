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
    // 6-column row (the extension format) — plan writes 4 columns, so this
    // is malformed for the driver's contract.
    final dir = await seed('''
# Test List: 090-fixture

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | fine | FR-001 | PENDING |
| U2 | six column row | FR-002 | example | PENDING |  |
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
}
